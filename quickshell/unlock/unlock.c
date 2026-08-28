// qsshell-unlock — authenticate the current user against PAM (WP-14 lock).
// Reads the password from stdin (up to a newline / EOF), runs the
// `qsshell-lock` PAM service, exits 0 on success and 1 on failure. Not setuid:
// pam_unix delegates the shadow check to the setuid unix_chkpwd helper, so a
// plain user process authenticates fine.
#define _GNU_SOURCE
#include <security/pam_appl.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static char *g_pw;

static int conv(int n, const struct pam_message **msg,
                struct pam_response **resp, void *data) {
  (void)data;
  struct pam_response *r = calloc(n, sizeof *r);
  if (!r) return PAM_BUF_ERR;
  for (int i = 0; i < n; i++)
    if (msg[i]->msg_style == PAM_PROMPT_ECHO_OFF ||
        msg[i]->msg_style == PAM_PROMPT_ECHO_ON)
      r[i].resp = strdup(g_pw ? g_pw : "");
  *resp = r;
  return PAM_SUCCESS;
}

int main(void) {
  char buf[1024];
  if (!fgets(buf, sizeof buf, stdin)) return 1;
  buf[strcspn(buf, "\n")] = 0;
  g_pw = buf;

  const char *user = getenv("USER");
  if (!user || !*user) {
    struct passwd *pw = getpwuid(getuid());
    user = pw ? pw->pw_name : NULL;
  }
  if (!user) return 1;

  struct pam_conv pc = {conv, NULL};
  pam_handle_t *ph;
  if (pam_start("qsshell-lock", user, &pc, &ph) != PAM_SUCCESS) return 1;
  int rc = pam_authenticate(ph, 0);
  if (rc == PAM_SUCCESS) rc = pam_acct_mgmt(ph, 0);
  pam_end(ph, rc);
  explicit_bzero(buf, sizeof buf);  // scrub the password
  return rc == PAM_SUCCESS ? 0 : 1;
}
