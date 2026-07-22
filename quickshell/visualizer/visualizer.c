#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <signal.h>
#include <string.h>
#include <pulse/simple.h>
#include <pulse/error.h>

#define SAMPLE_RATE 44100
#define FFT_SIZE 512
#define NUM_BARS 40
#define FREQ_MIN 50.0
#define FREQ_MAX 10000.0
#define M_PI 3.14159265358979323846

static volatile int running = 1;

static void sighandler(int sig) {
  (void)sig;
  running = 0;
}

int main(void) {
  signal(SIGINT, sighandler);
  signal(SIGTERM, sighandler);

  pa_sample_spec ss = {PA_SAMPLE_FLOAT32LE, SAMPLE_RATE, 1};
  int error;
  pa_simple *pa = pa_simple_new(NULL, "visualizer", PA_STREAM_RECORD, NULL, "monitor", &ss, NULL, NULL, &error);
  if (!pa) {
    fprintf(stderr, "pa_simple_new: %s\n", pa_strerror(error));
    return 1;
  }

  float window[FFT_SIZE];
  for (int i = 0; i < FFT_SIZE; i++)
    window[i] = 0.5f * (1.0f - cosf(2.0f * M_PI * i / (FFT_SIZE - 1)));

  double binFreqs[NUM_BARS];
  for (int i = 0; i < NUM_BARS; i++) {
    double t = (double)i / (NUM_BARS - 1);
    binFreqs[i] = FREQ_MIN * pow(FREQ_MAX / FREQ_MIN, t);
  }

  float buf[FFT_SIZE];
  double prev[NUM_BARS];
  double peak[NUM_BARS];
  memset(prev, 0, sizeof(prev));
  memset(peak, 0, sizeof(peak));

  while (running) {
    if (pa_simple_read(pa, buf, sizeof(buf), &error) < 0) break;

    float windowed[FFT_SIZE];
    for (int i = 0; i < FFT_SIZE; i++)
      windowed[i] = buf[i] * window[i];

    double bars[NUM_BARS];
    for (int k = 0; k < NUM_BARS; k++) {
      double re = 0, im = 0;
      double w = 2.0 * M_PI * binFreqs[k] / SAMPLE_RATE;
      for (int n = 0; n < FFT_SIZE; n++) {
        double angle = w * n;
        re += windowed[n] * cos(angle);
        im -= windowed[n] * sin(angle);
      }
      bars[k] = sqrt(re * re + im * im) / (FFT_SIZE * 0.5);
    }

    for (int k = 0; k < NUM_BARS; k++) {
      double v = bars[k] * 4.0;
      if (v > 1.0) v = 1.0;
      if (v > peak[k]) peak[k] = v;
      else peak[k] *= 0.995;
      prev[k] = prev[k] * 0.35 + v * 0.65;
      double out = prev[k] * 0.7 + peak[k] * 0.3;
      if (out < 0.005) out = 0;
      printf("%.3f\n", out);
    }
    fflush(stdout);
  }

  pa_simple_free(pa);
  return 0;
}
