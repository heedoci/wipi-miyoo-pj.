#define _POSIX_C_SOURCE 200809L
#include <SDL2/SDL.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#include "wipi_host.h"

#define WIPI_W 240
#define WIPI_H 320
#define FRAME_BYTES (WIPI_W * WIPI_H * 4)
#define PERF_LOG_SECONDS 5.0

typedef enum {
    P_UP, P_DOWN, P_LEFT, P_RIGHT,
    P_A, P_B, P_X, P_Y,
    P_L1, P_R1, P_L2, P_R2,
    P_START,
    P_COUNT
} PhysicalKey;

static const char *active_wipi_key[P_COUNT];
static int keypad_mode = 0;
static int running = 1;

static double monotonic_seconds(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return 0.0;
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1000000000.0;
}

static void mkdir_p(const char *path) {
    char tmp[512];
    size_t len;
    if (!path || !*path) return;
    snprintf(tmp, sizeof(tmp), "%s", path);
    len = strlen(tmp);
    if (len == 0) return;
    if (tmp[len - 1] == '/') tmp[len - 1] = '\0';
    for (char *p = tmp + 1; *p; ++p) {
        if (*p == '/') {
            *p = '\0';
            if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
                fprintf(stderr, "mkdir %s failed: %s\n", tmp, strerror(errno));
            }
            *p = '/';
        }
    }
    if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
        fprintf(stderr, "mkdir %s failed: %s\n", tmp, strerror(errno));
    }
}

static uint8_t *read_file(const char *path, size_t *out_len) {
    FILE *f = fopen(path, "rb");
    long size;
    uint8_t *buf;
    if (!f) return NULL;
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return NULL; }
    size = ftell(f);
    if (size <= 0) { fclose(f); return NULL; }
    rewind(f);
    buf = (uint8_t *)malloc((size_t)size);
    if (!buf) { fclose(f); return NULL; }
    if (fread(buf, 1, (size_t)size, f) != (size_t)size) {
        free(buf); fclose(f); return NULL;
    }
    fclose(f);
    *out_len = (size_t)size;
    return buf;
}

static const char *base_name(const char *path) {
    const char *p = strrchr(path, '/');
    return p ? p + 1 : path;
}

static int physical_from_sdl(SDL_Keycode key) {
    switch (key) {
        case SDLK_UP: return P_UP;
        case SDLK_DOWN: return P_DOWN;
        case SDLK_LEFT: return P_LEFT;
        case SDLK_RIGHT: return P_RIGHT;
        case SDLK_SPACE: return P_A;       /* Miyoo A */
        case SDLK_LCTRL: return P_B;       /* Miyoo B */
        case SDLK_LSHIFT: return P_X;      /* Miyoo X */
        case SDLK_LALT: return P_Y;        /* Miyoo Y */
        case SDLK_e: return P_L1;
        case SDLK_t: return P_R1;
        case SDLK_TAB: return P_L2;
        case SDLK_BACKSPACE: return P_R2;
        case SDLK_RETURN: return P_START;
        default: return -1;
    }
}

static const char *map_normal(PhysicalKey p) {
    static const char *map[P_COUNT] = {
        [P_UP] = "UP", [P_DOWN] = "DOWN", [P_LEFT] = "LEFT", [P_RIGHT] = "RIGHT",
        [P_A] = "OK", [P_B] = "CLR", [P_X] = "SOFT_L", [P_Y] = "SOFT_R",
        [P_L1] = "*", [P_R1] = "#", [P_L2] = "CALL", [P_R2] = "HANGUP",
        [P_START] = "OK"
    };
    return map[p];
}

static const char *map_keypad(PhysicalKey p) {
    static const char *map[P_COUNT] = {
        [P_UP] = "2", [P_DOWN] = "8", [P_LEFT] = "4", [P_RIGHT] = "6",
        [P_A] = "5", [P_B] = "0", [P_X] = "1", [P_Y] = "3",
        [P_L1] = "7", [P_R1] = "9", [P_L2] = "*", [P_R2] = "#",
        [P_START] = "5"
    };
    return map[p];
}

static void key_down_physical(PhysicalKey p) {
    if (p < 0 || p >= P_COUNT || active_wipi_key[p]) return;
    const char *wkey = keypad_mode ? map_keypad(p) : map_normal(p);
    if (!wkey) return;
    active_wipi_key[p] = wkey;
    wipi_key_down(wkey);
}

static void key_up_physical(PhysicalKey p) {
    if (p < 0 || p >= P_COUNT || !active_wipi_key[p]) return;
    wipi_key_up(active_wipi_key[p]);
    active_wipi_key[p] = NULL;
}

static void release_all_keys(void) {
    for (int i = 0; i < P_COUNT; ++i) key_up_physical((PhysicalKey)i);
}

static void handle_event(const SDL_Event *ev) {
    if (ev->type == SDL_QUIT) {
        running = 0;
        return;
    }
    if (ev->type != SDL_KEYDOWN && ev->type != SDL_KEYUP) return;

    const int down = ev->type == SDL_KEYDOWN;
    const SDL_Keycode sym = ev->key.keysym.sym;
    if (down && ev->key.repeat) return;

    /* Miyoo SELECT is Right Ctrl: hold it for numeric keypad mode. */
    if (sym == SDLK_RCTRL) {
        keypad_mode = down ? 1 : 0;
        return;
    }

    /* Miyoo MENU is Home: exit cleanly. */
    if (sym == SDLK_HOME && down) {
        running = 0;
        return;
    }

    int p = physical_from_sdl(sym);
    if (p < 0) return;
    if (down) key_down_physical((PhysicalKey)p);
    else key_up_physical((PhysicalKey)p);
}

static int print_core_error_if_any(void) {
    char err[2048] = {0};
    uint8_t kind = 0;
    if (!wipi_get_error(err, sizeof(err), &kind)) return 0;
    fprintf(stderr, "WIPI core error (%s): %s\n",
            kind == 0 ? "load" : "runtime", err);
    return 1;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <game.zip|game.jar> [data_dir]\n", argv[0]);
        return 2;
    }

    const char *rom_path = argv[1];
    const char *data_dir = argc >= 3 ? argv[2] : "/mnt/SDCARD/Saves/CurrentProfile/saves/WIPI";
    size_t rom_len = 0;
    uint8_t *rom_data = read_file(rom_path, &rom_len);
    uint8_t *frame = NULL;
    SDL_Window *window = NULL;
    SDL_Renderer *renderer = NULL;
    SDL_Texture *texture = NULL;
    int core_started = 0;
    int rc = 1;

    if (!rom_data) {
        fprintf(stderr, "failed to read ROM: %s\n", rom_path);
        return 3;
    }

    fprintf(stderr, "[perf] speed-test build; rom=%s bytes=%lu\n",
            base_name(rom_path), (unsigned long)rom_len);
    fflush(stderr);

    mkdir_p(data_dir);
    wipi_init();
    if (!wipi_start(rom_data, rom_len, base_name(rom_path), data_dir, "")) {
        fprintf(stderr, "wipi_start failed\n");
        print_core_error_if_any();
        goto cleanup;
    }
    core_started = 1;

    /* MVP starts silent. The bundled core patch removes rodio/rustysynth. */
    wipi_set_volume(0.0f, 0.0f);

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) != 0) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        goto cleanup;
    }

    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0");
    window = SDL_CreateWindow("WIPI", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                              640, 480, SDL_WINDOW_SHOWN);
    if (!window) {
        fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
        goto cleanup;
    }

    /* Speed test: do not request PRESENTVSYNC. We want renderer presentation
       to return immediately so it cannot throttle a slow emulation core. */
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (!renderer) renderer = SDL_CreateRenderer(window, -1, 0);
    if (!renderer) {
        fprintf(stderr, "SDL_CreateRenderer failed: %s\n", SDL_GetError());
        goto cleanup;
    }
    fprintf(stderr, "[perf] renderer created; vsync request disabled\n");
    fflush(stderr);

    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA32,
                                SDL_TEXTUREACCESS_STREAMING, WIPI_W, WIPI_H);
    if (!texture) {
        fprintf(stderr, "SDL_CreateTexture failed: %s\n", SDL_GetError());
        goto cleanup;
    }

    frame = (uint8_t *)malloc(FRAME_BYTES);
    if (!frame) goto cleanup;

    /* 240x320 -> 360x480, centered on Miyoo's 640x480 panel. */
    const SDL_Rect dst = {140, 0, 360, 480};
    double perf_last = monotonic_seconds();
    unsigned perf_frames = 0;
    unsigned long long perf_total = 0;

    while (running) {
        SDL_Event ev;
        while (SDL_PollEvent(&ev)) handle_event(&ev);

        if (wipi_poll_exit() > 0) {
            running = 0;
            break;
        }

        if (wipi_get_frame(frame, FRAME_BYTES)) {
            ++perf_frames;
            ++perf_total;
            SDL_UpdateTexture(texture, NULL, frame, WIPI_W * 4);
            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
            SDL_RenderClear(renderer);
            SDL_RenderCopy(renderer, texture, NULL, &dst);
            SDL_RenderPresent(renderer);
        }

        {
            const double now = monotonic_seconds();
            const double elapsed = now - perf_last;
            if (perf_last > 0.0 && elapsed >= PERF_LOG_SECONDS) {
                const double fps = (double)perf_frames / elapsed;
                fprintf(stderr, "[perf] WIPI output %.2f fps (%u frames / %.2fs), total=%llu\n",
                        fps, perf_frames, elapsed, perf_total);
                fflush(stderr);
                perf_frames = 0;
                perf_last = now;
            }
        }

        if (print_core_error_if_any()) {
            running = 0;
        }
        SDL_Delay(1);
    }

    rc = 0;

cleanup:
    release_all_keys();
    if (core_started) wipi_stop();
    free(frame);
    if (texture) SDL_DestroyTexture(texture);
    if (renderer) SDL_DestroyRenderer(renderer);
    if (window) SDL_DestroyWindow(window);
    SDL_Quit();
    free(rom_data);
    return rc;
}
