#include "../src/app.h"

#include <stdio.h>

static void respond_auth_error(int client, const char *message) {
  char escaped[512];
  char json[768];
  json_escape(escaped, sizeof(escaped), message);
  snprintf(json, sizeof(json), "{\"ok\":false,\"error\":\"%s\"}", escaped);
  respond_json(client, "422 Unprocessable Entity", NULL, json);
}

static void respond_user_session(int client, const char *email, const char *token) {
  char cookie[512];
  char escaped_email[512];
  char json[1024];
  json_escape(escaped_email, sizeof(escaped_email), email);
  snprintf(
    cookie,
    sizeof(cookie),
    "Set-Cookie: sealion_session=%s; HttpOnly; SameSite=Lax; Path=/; Max-Age=604800\r\n",
    token
  );
  snprintf(json, sizeof(json), "{\"ok\":true,\"user\":{\"email\":\"%s\"}}", escaped_email);
  respond_json(client, "200 OK", cookie, json);
}

void handle_register(int client, const Request *req) {
  char email[256];
  char password[256];
  char error[512];
  form_value(req->body, "email", email, sizeof(email));
  form_value(req->body, "password", password, sizeof(password));
  if (!create_user(email, password, error, sizeof(error))) {
    respond_auth_error(client, error);
    return;
  }
  int user_id = 0;
  lookup_user_id(email, &user_id);
  char token[129];
  if (!create_session(user_id, token, sizeof(token))) {
    respond_auth_error(client, "Account created, but login failed. Try logging in.");
    return;
  }
  respond_user_session(client, email, token);
}

void handle_login(int client, const Request *req) {
  char email[256];
  char password[256];
  int user_id = 0;
  form_value(req->body, "email", email, sizeof(email));
  form_value(req->body, "password", password, sizeof(password));
  if (!verify_user(email, password, &user_id)) {
    respond_auth_error(client, "Email or password is incorrect.");
    return;
  }
  char token[129];
  if (!create_session(user_id, token, sizeof(token))) {
    respond_auth_error(client, "Could not create a session.");
    return;
  }
  respond_user_session(client, email, token);
}

void handle_logout(int client, const Request *req) {
  destroy_session(req->cookie);
  respond_json(
    client,
    "200 OK",
    "Set-Cookie: sealion_session=deleted; HttpOnly; SameSite=Lax; Path=/; Max-Age=0\r\n",
    "{\"ok\":true}"
  );
}
