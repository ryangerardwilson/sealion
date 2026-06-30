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

PGconn *db = NULL;

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
  size_t body_len = strlen(body ? body : "");
  bool has_content_type = headers && strcasestr(headers, "Content-Type:") != NULL;
  int n = snprintf(
    head,
    sizeof(head),
    "HTTP/1.1 %s\r\n"
    "%s"
    "Content-Length: %zu\r\n"
    "Connection: close\r\n"
    "%s"
    "\r\n",
    status,
    has_content_type ? "" : "Content-Type: text/plain; charset=utf-8\r\n",
    body_len,
    headers ? headers : ""
  );
  send_all(client, head, (size_t)n);
  send_all(client, body ? body : "", body_len);
}

void respond_json(int client, const char *status, const char *headers, const char *json) {
  char merged[2048];
  snprintf(
    merged,
    sizeof(merged),
    "Content-Type: application/json; charset=utf-8\r\n"
    "Cache-Control: no-store\r\n"
    "%s",
    headers ? headers : ""
  );
  respond(client, status, merged, json ? json : "{}");
}

void json_escape(char *out, size_t out_len, const char *value) {
  size_t used = 0;
  const char *p = value ? value : "";
  if (out_len == 0) return;
  while (*p && used + 1 < out_len) {
    switch (*p) {
      case '\\':
      case '"':
        if (used + 2 >= out_len) {
          out[used] = '\0';
          return;
        }
        out[used++] = '\\';
        out[used++] = *p;
        break;
      case '\n':
        if (used + 2 >= out_len) {
          out[used] = '\0';
          return;
        }
        out[used++] = '\\';
        out[used++] = 'n';
        break;
      case '\r':
        if (used + 2 >= out_len) {
          out[used] = '\0';
          return;
        }
        out[used++] = '\\';
        out[used++] = 'r';
        break;
      case '\t':
        if (used + 2 >= out_len) {
          out[used] = '\0';
          return;
        }
        out[used++] = '\\';
        out[used++] = 't';
        break;
      default:
        out[used++] = *p;
        break;
    }
    p++;
  }
  out[used] = '\0';
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
    if (in[i] == '+') {
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
  } else if (strcmp(req.method, "GET") == 0 && strcmp(req.path, "/api/health") == 0) {
    respond_json(client, "200 OK", NULL, "{\"ok\":true}");
  } else if (strcmp(req.method, "GET") == 0 && strcmp(req.path, "/api/me") == 0) {
    handle_api_me(client, &req);
  } else if (strcmp(req.method, "GET") == 0 && strcmp(req.path, "/api/dashboard") == 0) {
    handle_api_dashboard(client, &req);
  } else if (strcmp(req.method, "POST") == 0 && strcmp(req.path, "/api/register") == 0) {
    handle_register(client, &req);
  } else if (strcmp(req.method, "POST") == 0 && strcmp(req.path, "/api/login") == 0) {
    handle_login(client, &req);
  } else if (strcmp(req.method, "POST") == 0 && strcmp(req.path, "/api/logout") == 0) {
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

  printf("%s API listening inside backend container on :%d\n", APP_NAME, port);
  if (public_url) {
    printf("frontend proxies API calls from %s/api\n", public_url);
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
