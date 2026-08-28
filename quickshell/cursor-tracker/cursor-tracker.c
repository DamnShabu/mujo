#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <grp.h>
#include <string.h>
#include <poll.h>
#include <linux/input.h>
#include <errno.h>
#include <dirent.h>
#include <time.h>

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
    fds[nfds].revents = 0;
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

    int device_error = 0;
    int ticks = 0;
    static long long last_emit_us = 0;
    while (!device_error) {
      int ret = poll(fds, nfds, 500);
      if (ret < 0) {
        if (errno == EINTR) continue;
        break;
      }

      int moved = 0;
      for (int i = 0; i < nfds; i++) {
        if (fds[i].revents & (POLLERR | POLLHUP | POLLNVAL)) {
          device_error = 1;
          break;
        }
        if (!(fds[i].revents & POLLIN)) continue;
        struct input_event ev;
        while (1) {
          ssize_t n = read(fds[i].fd, &ev, sizeof(ev));
          if (n == sizeof(ev)) {
            if (ev.type == EV_REL) {
              if (ev.code == REL_X) { cx += (double)ev.value / screen_w; moved = 1; }
              else if (ev.code == REL_Y) { cy += (double)ev.value / screen_h; moved = 1; }
            }
          } else if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            break;
          } else {
            device_error = 1;
            break;
          }
        }
        if (device_error) break;
      }
      // Emit at most once per ~16ms. A gaming mouse reports at up to 1000Hz and
      // every line here becomes a JSON.parse on quickshell's main thread (see
      // Wallpaper.qml); a parallax effect cannot show more than one update per
      // frame regardless.
      if (moved) {
        struct timespec now;
        clock_gettime(CLOCK_MONOTONIC, &now);
        long long now_us = (long long)now.tv_sec * 1000000 + now.tv_nsec / 1000;
        if (now_us - last_emit_us >= 16000) {
          last_emit_us = now_us;
          if (cx < 0.0) cx = 0.0; if (cx > 1.0) cx = 1.0;
          if (cy < 0.0) cy = 0.0; if (cy > 1.0) cy = 1.0;
          printf("{\"x\":%.4f,\"y\":%.4f}\n", cx, cy);
          fflush(stdout);
        }
      }
      // Rescan for newly connected devices roughly every 5s. This counts only
      // poll() *timeouts*: counting every return meant that while the mouse was
      // moving, ret>0 fired constantly and the 10-tick budget was spent in a
      // fraction of a second, re-opendir-ing /dev/input and reopening every
      // event device ~100x a second.
      if (ret == 0 && ++ticks > 10) {
        ticks = 0;
        break;
      }
    }

    for (int i = 0; i < nfds; i++) close(fds[i].fd);
  }

  return 0;
}
