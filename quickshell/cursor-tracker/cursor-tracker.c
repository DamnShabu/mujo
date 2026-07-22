#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <grp.h>
#include <string.h>
#include <poll.h>
#include <linux/input.h>
#include <dirent.h>

#define MAX_DEVS 32

int open_rel_devices(struct pollfd *fds) {
  int nfds = 0;
  DIR *dir = opendir("/dev/input");
  if (!dir) return 0;

  struct dirent *ent;
  while ((ent = readdir(dir)) && nfds < MAX_DEVS) {
    if (strncmp(ent->d_name, "event", 5) != 0) continue;
    char path[256];
    snprintf(path, sizeof(path), "/dev/input/%s", ent->d_name);
    int fd = open(path, O_RDONLY | O_NONBLOCK);
    if (fd < 0) continue;

    unsigned long bits = 0;
    if (ioctl(fd, EVIOCGBIT(0, sizeof(bits)), &bits) < 0 || !(bits & (1 << EV_REL))) {
      close(fd);
      continue;
    }
    fds[nfds].fd = fd;
    fds[nfds].events = POLLIN;
    nfds++;
  }
  closedir(dir);
  return nfds;
}

int main(int argc, char *argv[]) {
  int screen_w = 1920, screen_h = 1080;
  if (argc >= 3) {
    screen_w = atoi(argv[1]);
    screen_h = atoi(argv[2]);
  }
  if (screen_w <= 0) screen_w = 1920;
  if (screen_h <= 0) screen_h = 1080;

  double cx = 0.5, cy = 0.5;

  while (1) {
    struct pollfd fds[MAX_DEVS];
    int nfds = open_rel_devices(fds);

    if (nfds == 0) {
      sleep(1);
      continue;
    }

    while (nfds > 0) {
      int ret = poll(fds, nfds, 100);
      if (ret < 0) break;

      int moved = 0;
      for (int i = 0; i < nfds; i++) {
        if (!(fds[i].revents & POLLIN)) continue;
        struct input_event ev;
        while (read(fds[i].fd, &ev, sizeof(ev)) == sizeof(ev)) {
          if (ev.type == EV_REL) {
            if (ev.code == REL_X) { cx += (double)ev.value / screen_w; moved = 1; }
            else if (ev.code == REL_Y) { cy += (double)ev.value / screen_h; moved = 1; }
          }
        }
      }
      if (moved) {
        if (cx < 0.0) cx = 0.0; if (cx > 1.0) cx = 1.0;
        if (cy < 0.0) cy = 0.0; if (cy > 1.0) cy = 1.0;
        printf("{\"x\":%.4f,\"y\":%.4f}\n", cx, cy);
        fflush(stdout);
      }
    }

    for (int i = 0; i < nfds; i++) close(fds[i].fd);
  }

  return 0;
}
