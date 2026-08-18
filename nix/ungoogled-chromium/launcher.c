#include <limits.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
  (void)argc;

  const char *home = getenv("HOME");
  if (home == NULL || home[0] == '\0') {
    const struct passwd *user = getpwuid(getuid());
    if (user != NULL) {
      home = user->pw_dir;
    }
  }

  if (home == NULL || home[0] == '\0') {
    fputs("ungoogled-chromium-launcher: cannot determine the home directory\n",
          stderr);
    return 1;
  }

  char executable[PATH_MAX];
  const int length = snprintf(
      executable, sizeof(executable),
      "%s/.nix-profile/Applications/Chromium.app/Contents/MacOS/Chromium", home);
  if (length < 0 || (size_t)length >= sizeof(executable)) {
    fputs("ungoogled-chromium-launcher: browser path is too long\n", stderr);
    return 1;
  }

  argv[0] = executable;
  execv(executable, argv);
  perror("ungoogled-chromium-launcher");
  return 1;
}
