#define _GNU_SOURCE

#include "app.h"

#include <arpa/inet.h>
#include <ctype.h>
#include <errno.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#define MAX_COMPONENT_DEPTH 8
#define MAX_COMPONENT_PROPS 24
#define MAX_PROP_NAME 64
#define MAX_PROP_VALUE 512

PGconn *db = NULL;

typedef enum {
  TEMPLATE_SKIN = 0,
  TEMPLATE_L1 = 1,
  TEMPLATE_L2 = 2,
  TEMPLATE_L3 = 3
} TemplateLevel;

void fatal(const char *message) {
  fprintf(stderr, "%s\n", message);
  exit(1);
}

static void send_all(int client, const char *data, size_t len) {
  size_t sent = 0;
  while (sent < len) {
    ssize_t n = send(client, data + sent, len - sent, 0);
    if (n <= 0) {
      return;
    }
    sent += (size_t)n;
  }
}

void respond(int client, const char *status, const char *headers, const char *body) {
  char head[2048];
  size_t body_len = strlen(body);
  int n = snprintf(
    head,
    sizeof(head),
    "HTTP/1.1 %s\r\n"
    "Content-Type: text/html; charset=utf-8\r\n"
    "Content-Length: %zu\r\n"
    "Connection: close\r\n"
    "%s"
    "\r\n",
    status,
    body_len,
    headers ? headers : ""
  );
  send_all(client, head, (size_t)n);
  send_all(client, body, body_len);
}

void redirect_to(int client, const char *location, const char *extra_headers) {
  char headers[1024];
  char body[1024];
  snprintf(
    headers,
    sizeof(headers),
    "Location: %s\r\n"
    "Cache-Control: no-store\r\n"
    "%s",
    location,
    extra_headers ? extra_headers : ""
  );
  snprintf(
    body,
    sizeof(body),
    "<!doctype html><title>Redirecting</title>"
    "<meta http-equiv=\"refresh\" content=\"0;url=%s\">"
    "<script>window.location.replace('%s');</script>"
    "<p><a href=\"%s\">Continue</a></p>",
    location,
    location,
    location
  );
  respond(client, "302 Found", headers, body);
}

static bool append_bytes(char *out, size_t out_len, size_t *used, const char *data, size_t data_len) {
  if (*used >= out_len) return false;
  size_t remaining = out_len - *used - 1;
  bool ok = data_len <= remaining;
  size_t copy_len = ok ? data_len : remaining;
  if (copy_len > 0) {
    memcpy(out + *used, data, copy_len);
    *used += copy_len;
  }
  out[*used] = '\0';
  return ok;
}

static bool append_text(char *out, size_t out_len, size_t *used, const char *text) {
  return append_bytes(out, out_len, used, text ? text : "", strlen(text ? text : ""));
}

static bool append_escaped(char *out, size_t out_len, size_t *used, const char *text) {
  const char *p = text ? text : "";
  while (*p) {
    switch (*p) {
      case '&':
        if (!append_text(out, out_len, used, "&amp;")) return false;
        break;
      case '<':
        if (!append_text(out, out_len, used, "&lt;")) return false;
        break;
      case '>':
        if (!append_text(out, out_len, used, "&gt;")) return false;
        break;
      case '"':
        if (!append_text(out, out_len, used, "&quot;")) return false;
        break;
      case '\'':
        if (!append_text(out, out_len, used, "&#39;")) return false;
        break;
      default:
        if (!append_bytes(out, out_len, used, p, 1)) return false;
        break;
    }
    p++;
  }
  return true;
}

static const char *view_var_value(const ViewVar *vars, size_t var_count, const char *name) {
  for (size_t i = 0; i < var_count; i++) {
    if (strcmp(vars[i].name, name) == 0) {
      return vars[i].value ? vars[i].value : "";
    }
  }
  return "";
}

static bool find_view_var(const ViewVar *vars, size_t var_count, const char *name, const char **value) {
  for (size_t i = 0; i < var_count; i++) {
    if (strcmp(vars[i].name, name) == 0) {
      *value = vars[i].value ? vars[i].value : "";
      return true;
    }
  }
  return false;
}

static void copy_trimmed_key(char *out, size_t out_len, const char *start, size_t len) {
  while (len > 0 && isspace((unsigned char)*start)) {
    start++;
    len--;
  }
  while (len > 0 && isspace((unsigned char)start[len - 1])) {
    len--;
  }
  if (len >= out_len) len = out_len - 1;
  memcpy(out, start, len);
  out[len] = '\0';
}

static bool read_template_file(const char *path, char *out, size_t out_len) {
  FILE *file = fopen(path, "rb");
  if (!file) return false;
  size_t n = fread(out, 1, out_len - 1, file);
  out[n] = '\0';
  bool ok = feof(file);
  fclose(file);
  return ok;
}

static const char *first_token(const char *cursor, const char **component, const char **raw, const char **escaped) {
  *component = strstr(cursor, "<s-");
  *raw = strstr(cursor, "{!!");
  *escaped = strstr(cursor, "{{");
  const char *first = NULL;
  if (*component) first = *component;
  if (*raw && (!first || *raw < first)) first = *raw;
  if (*escaped && (!first || *escaped < first)) first = *escaped;
  return first;
}

static bool component_name_is_safe(const char *name) {
  if (!name[0] || name[0] == '/' || strstr(name, "..")) return false;
  for (const char *p = name; *p; p++) {
    if (!(isalnum((unsigned char)*p) || *p == '_' || *p == '/')) {
      return false;
    }
  }
  return true;
}

static bool prop_name_is_safe(const char *name) {
  if (!name[0]) return false;
  for (const char *p = name; *p; p++) {
    if (!(isalnum((unsigned char)*p) || *p == '_')) {
      return false;
    }
  }
  return true;
}

static bool copy_component_path(char *out, size_t out_len, const char *start, size_t len) {
  if (len == 0 || len >= out_len) return false;
  for (size_t i = 0; i < len; i++) {
    char c = start[i];
    if (c == '.') {
      out[i] = '/';
    } else if (c == '-') {
      out[i] = '_';
    } else if (isalnum((unsigned char)c) || c == '_') {
      out[i] = c;
    } else {
      return false;
    }
  }
  out[len] = '\0';
  return component_name_is_safe(out);
}

static bool copy_component_tag_name(char *out, size_t out_len, const char *start, size_t len) {
  if (len == 0 || len >= out_len) return false;
  for (size_t i = 0; i < len; i++) {
    char c = start[i];
    if (!(isalnum((unsigned char)c) || c == '_' || c == '-' || c == '.')) {
      return false;
    }
    out[i] = c;
  }
  out[len] = '\0';
  return true;
}

static bool component_level_from_name(const char *name, TemplateLevel *level) {
  if (strncmp(name, "l1/", 3) == 0 && name[3]) {
    *level = TEMPLATE_L1;
    return true;
  }
  if (strncmp(name, "l2/", 3) == 0 && name[3]) {
    *level = TEMPLATE_L2;
    return true;
  }
  if (strncmp(name, "l3/", 3) == 0 && name[3]) {
    *level = TEMPLATE_L3;
    return true;
  }
  return false;
}

static const char *template_level_name(TemplateLevel level) {
  switch (level) {
    case TEMPLATE_SKIN:
      return "skin";
    case TEMPLATE_L1:
      return "l1";
    case TEMPLATE_L2:
      return "l2";
    case TEMPLATE_L3:
      return "l3";
  }
  return "unknown";
}

static bool component_allowed_in_context(TemplateLevel context, TemplateLevel target) {
  switch (context) {
    case TEMPLATE_SKIN:
      return target == TEMPLATE_L2 || target == TEMPLATE_L3;
    case TEMPLATE_L1:
      return false;
    case TEMPLATE_L2:
      return target == TEMPLATE_L1;
    case TEMPLATE_L3:
      return target == TEMPLATE_L1 || target == TEMPLATE_L2;
  }
  return false;
}

static bool copy_prop_name(char *out, size_t out_len, const char *start, size_t len) {
  if (len == 0 || len >= out_len) return false;
  for (size_t i = 0; i < len; i++) {
    char c = start[i];
    if (c == '-') {
      out[i] = '_';
    } else if (isalnum((unsigned char)c) || c == '_') {
      out[i] = c;
    } else {
      return false;
    }
  }
  out[len] = '\0';
  return prop_name_is_safe(out);
}

static bool add_component_prop(
  const ViewVar *source_vars,
  size_t source_var_count,
  ViewVar *props,
  size_t *prop_count,
  char prop_names[MAX_COMPONENT_PROPS][MAX_PROP_NAME],
  const char *name_start,
  size_t name_len
) {
  if (*prop_count >= MAX_COMPONENT_PROPS) return false;
  char source_name[MAX_PROP_NAME];
  const char *value = NULL;
  if (!copy_prop_name(source_name, sizeof(source_name), name_start, name_len)) return false;
  if (!find_view_var(source_vars, source_var_count, source_name, &value)) return false;
  memcpy(prop_names[*prop_count], source_name, strlen(source_name) + 1);
  props[*prop_count] = (ViewVar){prop_names[*prop_count], value};
  (*prop_count)++;
  return true;
}

static bool parse_passover_props(
  const char **cursor,
  const ViewVar *source_vars,
  size_t source_var_count,
  ViewVar *props,
  size_t *prop_count,
  char prop_names[MAX_COMPONENT_PROPS][MAX_PROP_NAME]
) {
  const char *p = *cursor;
  bool quoted = false;
  if (*p == '"') {
    quoted = true;
    p++;
  }
  if (*p != '[') return false;
  p++;

  for (;;) {
    while (*p && isspace((unsigned char)*p)) p++;
    if (*p == ']') {
      p++;
      break;
    }

    const char *name_start = p;
    while (*p && (isalnum((unsigned char)*p) || *p == '_' || *p == '-')) p++;
    size_t name_len = (size_t)(p - name_start);
    if (!add_component_prop(
      source_vars,
      source_var_count,
      props,
      prop_count,
      prop_names,
      name_start,
      name_len
    )) {
      return false;
    }

    while (*p && isspace((unsigned char)*p)) p++;
    if (*p == ',') {
      p++;
      continue;
    }
    if (*p == ']') {
      p++;
      break;
    }
    return false;
  }

  if (quoted) {
    if (*p != '"') return false;
    p++;
  }
  *cursor = p;
  return true;
}

static bool add_raw_prop(
  ViewVar *props,
  size_t *prop_count,
  char prop_names[MAX_COMPONENT_PROPS][MAX_PROP_NAME],
  const char *name,
  const char *value
) {
  if (*prop_count >= MAX_COMPONENT_PROPS) return false;
  size_t name_len = strlen(name);
  if (name_len == 0 || name_len >= MAX_PROP_NAME) return false;
  memcpy(prop_names[*prop_count], name, name_len + 1);
  props[*prop_count] = (ViewVar){prop_names[*prop_count], value};
  (*prop_count)++;
  return true;
}

static bool component_open_matches(const char *candidate, const char *tag_name) {
  size_t tag_len = strlen(tag_name);
  if (strncmp(candidate, "<s-", 3) != 0) return false;
  if (strncmp(candidate + 3, tag_name, tag_len) != 0) return false;
  char next = candidate[3 + tag_len];
  return next == '>' || next == '/' || isspace((unsigned char)next);
}

static bool find_component_close(
  const char *content_start,
  const char *tag_name,
  const char **content_end,
  const char **end_out
) {
  char close_tag[160];
  int n = snprintf(close_tag, sizeof(close_tag), "</s-%s>", tag_name);
  if (n <= 0 || (size_t)n >= sizeof(close_tag)) return false;

  const char *p = content_start;
  int depth = 1;
  while (*p) {
    const char *next_open = strstr(p, "<s-");
    const char *next_close = strstr(p, close_tag);
    if (!next_close) return false;

    if (next_open && next_open < next_close && component_open_matches(next_open, tag_name)) {
      const char *open_end = strchr(next_open, '>');
      if (!open_end) return false;
      const char *tag_tail = open_end;
      while (tag_tail > next_open && isspace((unsigned char)tag_tail[-1])) tag_tail--;
      if (tag_tail == next_open || tag_tail[-1] != '/') depth++;
      p = open_end + 1;
      continue;
    }

    depth--;
    if (depth == 0) {
      *content_end = next_close;
      *end_out = next_close + (size_t)n;
      return true;
    }
    p = next_close + (size_t)n;
  }
  return false;
}

static bool parse_component_import(
  const char *start,
  const ViewVar *source_vars,
  size_t source_var_count,
  char *component_name,
  size_t component_name_len,
  char *component_tag_name,
  size_t component_tag_name_len,
  ViewVar *props,
  size_t *prop_count,
  char prop_names[MAX_COMPONENT_PROPS][MAX_PROP_NAME],
  char prop_literals[MAX_COMPONENT_PROPS][MAX_PROP_VALUE],
  bool *self_closing,
  const char **end_out
) {
  const char *p = start + strlen("<s-");
  *prop_count = 0;
  const char *name_start = p;
  while (*p && !isspace((unsigned char)*p) && *p != '/' && *p != '>') p++;
  size_t len = (size_t)(p - name_start);
  if (!copy_component_path(component_name, component_name_len, name_start, len)) return false;
  if (!copy_component_tag_name(component_tag_name, component_tag_name_len, name_start, len)) return false;

  for (;;) {
    while (*p && isspace((unsigned char)*p)) p++;
    if (p[0] == '/' && p[1] == '>') {
      *self_closing = true;
      *end_out = p + 2;
      return true;
    }
    if (*p == '>') {
      *self_closing = false;
      *end_out = p + 1;
      return true;
    }
    if (*prop_count >= MAX_COMPONENT_PROPS) return false;

    bool bind_variable = false;
    if (*p == ':') {
      bind_variable = true;
      p++;
    }

    const char *name_start = p;
    while (*p && (isalnum((unsigned char)*p) || *p == '_' || *p == '-')) p++;
    size_t prop_name_len = (size_t)(p - name_start);
    if (!copy_prop_name(prop_names[*prop_count], MAX_PROP_NAME, name_start, prop_name_len)) return false;

    while (*p && isspace((unsigned char)*p)) p++;
    if (*p != '=') return false;
    p++;
    while (*p && isspace((unsigned char)*p)) p++;

    if (bind_variable && strcmp(prop_names[*prop_count], "passover") == 0) {
      if (!parse_passover_props(
        &p,
        source_vars,
        source_var_count,
        props,
        prop_count,
        prop_names
      )) {
        return false;
      }
      continue;
    }

    const char *value = NULL;
    if (*p != '"') return false;
    p++;
    const char *value_start = p;
    while (*p && *p != '"') p++;
    if (*p != '"') return false;
    size_t value_len = (size_t)(p - value_start);

    if (bind_variable) {
      char source_name[MAX_PROP_NAME];
      if (!copy_prop_name(source_name, sizeof(source_name), value_start, value_len)) return false;
      if (!find_view_var(source_vars, source_var_count, source_name, &value)) return false;
    } else {
      size_t literal_len = value_len;
      if (literal_len >= MAX_PROP_VALUE) return false;
      memcpy(prop_literals[*prop_count], value_start, literal_len);
      prop_literals[*prop_count][literal_len] = '\0';
      value = prop_literals[*prop_count];
    }
    p++;

    props[*prop_count] = (ViewVar){prop_names[*prop_count], value};
    (*prop_count)++;
  }
}

static bool render_template_file(
  const char *path,
  const ViewVar *vars,
  size_t var_count,
  char *out,
  size_t out_len,
  TemplateLevel context,
  int depth
);

static bool render_component(
  const char *component_name,
  TemplateLevel context,
  const ViewVar *vars,
  size_t var_count,
  char *out,
  size_t out_len,
  int depth
) {
  char path[256];
  TemplateLevel target;
  if (depth >= MAX_COMPONENT_DEPTH) return false;
  if (!component_level_from_name(component_name, &target)) {
    fprintf(stderr, "template error: component s-%s must live under l1, l2, or l3\n", component_name);
    return false;
  }
  if (!component_allowed_in_context(context, target)) {
    fprintf(
      stderr,
      "template error: %s templates cannot use s-%s components\n",
      template_level_name(context),
      component_name
    );
    return false;
  }
  snprintf(path, sizeof(path), "ui_components/%s.scale", component_name);
  return render_template_file(path, vars, var_count, out, out_len, target, depth + 1);
}

static bool render_template_text(
  const char *template_text,
  const ViewVar *vars,
  size_t var_count,
  char *out,
  size_t out_len,
  TemplateLevel context,
  int depth
) {
  const char *cursor = template_text;
  size_t used = 0;
  out[0] = '\0';

  while (*cursor) {
    const char *component;
    const char *raw;
    const char *escaped;
    const char *start = first_token(cursor, &component, &raw, &escaped);
    if (!start) {
      return append_text(out, out_len, &used, cursor);
    }

    if (!append_bytes(out, out_len, &used, cursor, (size_t)(start - cursor))) return false;

    if (start == component) {
      char component_name[128];
      char component_tag_name[128];
      char prop_names[MAX_COMPONENT_PROPS][MAX_PROP_NAME];
      char prop_literals[MAX_COMPONENT_PROPS][MAX_PROP_VALUE];
      ViewVar props[MAX_COMPONENT_PROPS];
      size_t prop_count = 0;
      char rendered[MAX_VIEW];
      char *slot_template = NULL;
      char *slot_content = NULL;
      const char *end = NULL;
      bool self_closing = true;
      if (!parse_component_import(
        start,
        vars,
        var_count,
        component_name,
        sizeof(component_name),
        component_tag_name,
        sizeof(component_tag_name),
        props,
        &prop_count,
        prop_names,
        prop_literals,
        &self_closing,
        &end
      )) {
        return false;
      }

      if (!self_closing) {
        const char *content_end = NULL;
        const char *block_end = NULL;
        if (!find_component_close(end, component_tag_name, &content_end, &block_end)) {
          return false;
        }
        size_t slot_len = (size_t)(content_end - end);
        if (slot_len >= MAX_VIEW) return false;
        slot_template = malloc(MAX_VIEW);
        slot_content = malloc(MAX_VIEW);
        if (!slot_template || !slot_content) {
          free(slot_template);
          free(slot_content);
          return false;
        }
        memcpy(slot_template, end, slot_len);
        slot_template[slot_len] = '\0';
        if (!render_template_text(slot_template, vars, var_count, slot_content, MAX_VIEW, context, depth)) {
          free(slot_template);
          free(slot_content);
          return false;
        }
        if (!add_raw_prop(props, &prop_count, prop_names, "content", slot_content)) {
          free(slot_template);
          free(slot_content);
          return false;
        }
        end = block_end;
      }

      if (!render_component(component_name, context, props, prop_count, rendered, sizeof(rendered), depth)) {
        free(slot_template);
        free(slot_content);
        return false;
      }
      free(slot_template);
      free(slot_content);
      if (!append_text(out, out_len, &used, rendered)) return false;
      cursor = end;
      continue;
    }

    bool use_raw = start == raw;
    const char *token_start = start + (use_raw ? 3 : 2);
    const char *end = use_raw ? strstr(token_start, "!!}") : strstr(token_start, "}}");
    if (!end) {
      return append_text(out, out_len, &used, start);
    }

    char key[128];
    copy_trimmed_key(key, sizeof(key), token_start, (size_t)(end - token_start));
    const char *value = view_var_value(vars, var_count, key);
    if (use_raw) {
      if (!append_text(out, out_len, &used, value)) return false;
    } else {
      if (!append_escaped(out, out_len, &used, value)) return false;
    }

    cursor = end + (use_raw ? 3 : 2);
  }

  return true;
}

static bool render_template_file(
  const char *path,
  const ViewVar *vars,
  size_t var_count,
  char *out,
  size_t out_len,
  TemplateLevel context,
  int depth
) {
  char template_text[MAX_VIEW];
  if (!read_template_file(path, template_text, sizeof(template_text))) {
    return false;
  }
  return render_template_text(template_text, vars, var_count, out, out_len, context, depth);
}

static bool render_page(
  const char *view_name,
  const char *title,
  const ViewVar *vars,
  size_t var_count,
  char *out,
  size_t out_len
) {
  char view_path[256];
  snprintf(view_path, sizeof(view_path), "view/%s.skin", view_name);

  ViewVar view_vars[var_count + 2];
  view_vars[0] = (ViewVar){"title", title};
  view_vars[1] = (ViewVar){"app_name", APP_NAME};
  for (size_t i = 0; i < var_count; i++) {
    view_vars[i + 2] = vars[i];
  }
  return render_template_file(view_path, view_vars, var_count + 2, out, out_len, TEMPLATE_SKIN, 0);
}

void respond_view(
  int client,
  const char *status,
  const char *view_name,
  const char *title,
  const ViewVar *vars,
  size_t var_count
) {
  char page[MAX_VIEW];
  if (!render_page(view_name, title, vars, var_count, page, sizeof(page))) {
    respond(
      client,
      "500 Internal Server Error",
      NULL,
      "<!doctype html><title>Template error</title><p>Could not render the requested view.</p>"
    );
    return;
  }
  respond(client, status, NULL, page);
}

static int hex_value(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

static void url_decode(char *out, size_t out_len, const char *in, size_t in_len) {
  size_t o = 0;
  for (size_t i = 0; i < in_len && o + 1 < out_len; i++) {
    if (in[i] == '+' ) {
      out[o++] = ' ';
    } else if (in[i] == '%' && i + 2 < in_len) {
      int hi = hex_value(in[i + 1]);
      int lo = hex_value(in[i + 2]);
      if (hi >= 0 && lo >= 0) {
        out[o++] = (char)((hi << 4) | lo);
        i += 2;
      }
    } else {
      out[o++] = in[i];
    }
  }
  out[o] = '\0';
}

bool form_value(const char *body, const char *key, char *out, size_t out_len) {
  size_t key_len = strlen(key);
  const char *p = body ? body : "";
  while (*p) {
    const char *end = strchr(p, '&');
    size_t pair_len = end ? (size_t)(end - p) : strlen(p);
    if (pair_len > key_len && strncmp(p, key, key_len) == 0 && p[key_len] == '=') {
      url_decode(out, out_len, p + key_len + 1, pair_len - key_len - 1);
      return true;
    }
    if (!end) break;
    p = end + 1;
  }
  out[0] = '\0';
  return false;
}

static int parse_content_length(const char *headers) {
  const char *p = strcasestr(headers, "Content-Length:");
  if (!p) return 0;
  p += strlen("Content-Length:");
  while (*p == ' ') p++;
  return atoi(p);
}

static void parse_cookie_header(const char *headers, char *cookie, size_t cookie_len) {
  const char *name = "sealion_session=";
  size_t name_len = strlen(name);
  const char *p = headers;
  cookie[0] = '\0';

  while ((p = strcasestr(p, "\r\nCookie:")) != NULL) {
    p += strlen("\r\nCookie:");
    while (*p == ' ' || *p == '\t') p++;
    const char *line_end = strstr(p, "\r\n");
    if (!line_end) line_end = p + strlen(p);

    const char *item = p;
    while (item < line_end) {
      while (item < line_end && (*item == ' ' || *item == '\t' || *item == ';')) item++;
      const char *item_end = item;
      while (item_end < line_end && *item_end != ';') item_end++;
      while (item_end > item && (item_end[-1] == ' ' || item_end[-1] == '\t')) item_end--;

      if ((size_t)(item_end - item) > name_len && strncmp(item, name, name_len) == 0) {
        size_t value_len = (size_t)(item_end - item);
        if (value_len >= cookie_len) value_len = cookie_len - 1;
        memcpy(cookie, item, value_len);
        cookie[value_len] = '\0';
      }

      item = item_end < line_end ? item_end + 1 : line_end;
    }
  }
}

static bool read_request(int client, Request *req, char *buffer, size_t buffer_len) {
  size_t total = 0;
  int content_length = 0;
  char *header_end = NULL;
  memset(req, 0, sizeof(*req));
  while (total + 1 < buffer_len) {
    ssize_t n = recv(client, buffer + total, buffer_len - total - 1, 0);
    if (n <= 0) break;
    total += (size_t)n;
    buffer[total] = '\0';
    header_end = strstr(buffer, "\r\n\r\n");
    if (header_end) {
      content_length = parse_content_length(buffer);
      size_t header_len = (size_t)(header_end + 4 - buffer);
      if (total >= header_len + (size_t)content_length) break;
    }
  }
  if (!header_end) return false;

  sscanf(buffer, "%7s %1023s", req->method, req->path);
  char *query = strchr(req->path, '?');
  if (query) *query = '\0';
  parse_cookie_header(buffer, req->cookie, sizeof(req->cookie));
  req->body = header_end + 4;
  return true;
}

static bool wait_for_client_data(int client) {
  fd_set readfds;
  struct timeval timeout;
  int ready;

  FD_ZERO(&readfds);
  FD_SET(client, &readfds);
  timeout.tv_sec = 0;
  timeout.tv_usec = 250000;

  do {
    ready = select(client + 1, &readfds, NULL, NULL, &timeout);
  } while (ready < 0 && errno == EINTR);

  return ready > 0 && FD_ISSET(client, &readfds);
}

static void set_client_timeouts(int client) {
  struct timeval timeout;
  timeout.tv_sec = 2;
  timeout.tv_usec = 0;
  setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
  setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
}

static void handle_client(int client) {
  char buffer[MAX_REQUEST];
  Request req;
  set_client_timeouts(client);
  if (!wait_for_client_data(client)) {
    close(client);
    return;
  }
  if (!read_request(client, &req, buffer, sizeof(buffer))) {
    close(client);
    return;
  }

  printf("%s %s\n", req.method, req.path);
  fflush(stdout);

  if (strcmp(req.method, "GET") == 0 && strcmp(req.path, "/health") == 0) {
    respond(client, "200 OK", "Content-Type: text/plain; charset=utf-8\r\n", "ok\n");
  } else if (strcmp(req.method, "GET") == 0 && strcmp(req.path, "/") == 0) {
    handle_home(client, &req);
  } else if (strcmp(req.method, "GET") == 0 && strcmp(req.path, "/register") == 0) {
    handle_register_form(client, "");
  } else if (strcmp(req.method, "POST") == 0 && strcmp(req.path, "/register") == 0) {
    handle_register(client, &req);
  } else if (strcmp(req.method, "GET") == 0 && strcmp(req.path, "/login") == 0) {
    handle_login_form(client, "");
  } else if (strcmp(req.method, "POST") == 0 && strcmp(req.path, "/login") == 0) {
    handle_login(client, &req);
  } else if (strcmp(req.method, "GET") == 0 && strcmp(req.path, "/dashboard") == 0) {
    handle_dashboard(client, &req);
  } else if (strcmp(req.method, "POST") == 0 && strcmp(req.path, "/logout") == 0) {
    handle_logout(client, &req);
  } else {
    handle_not_found(client);
  }

  close(client);
}

int main(void) {
  const char *port_text = getenv("APP_PORT");
  const char *public_url = getenv("PUBLIC_URL");
  int port = port_text ? atoi(port_text) : 8080;
  if (port <= 0) port = 8080;
  if (public_url && public_url[0] == '\0') public_url = NULL;
  signal(SIGPIPE, SIG_IGN);

  connect_db();

  int server = socket(AF_INET, SOCK_STREAM, 0);
  if (server < 0) fatal("could not create socket");

  int yes = 1;
  setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  addr.sin_port = htons((uint16_t)port);

  if (bind(server, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    perror("bind");
    return 1;
  }
  if (listen(server, 64) < 0) {
    perror("listen");
    return 1;
  }

  if (public_url) {
    printf("%s listening inside container on :%d\n", APP_NAME, port);
    printf("open %s\n", public_url);
  } else {
    printf("%s listening on http://localhost:%d\n", APP_NAME, port);
  }
  fflush(stdout);

  for (;;) {
    int client = accept(server, NULL, NULL);
    if (client < 0) {
      if (errno == EINTR) continue;
      perror("accept");
      continue;
    }
    handle_client(client);
  }
}
