#ifndef FAKE_SDL_H
#define FAKE_SDL_H
#include <stdint.h>

typedef int32_t SDL_Keycode;
typedef struct SDL_Window SDL_Window;
typedef struct SDL_Renderer SDL_Renderer;
typedef struct SDL_Texture SDL_Texture;
typedef struct { int x,y,w,h; } SDL_Rect;
typedef struct { SDL_Keycode sym; } SDL_Keysym;
typedef struct { uint32_t type; uint8_t repeat; SDL_Keysym keysym; } SDL_KeyboardEvent;
typedef union { uint32_t type; SDL_KeyboardEvent key; } SDL_Event;

#define SDL_QUIT 0x100
#define SDL_KEYDOWN 0x300
#define SDL_KEYUP 0x301
#define SDL_INIT_VIDEO 0x20
#define SDL_INIT_EVENTS 0x4000
#define SDL_WINDOWPOS_UNDEFINED 0
#define SDL_WINDOW_SHOWN 4
#define SDL_RENDERER_ACCELERATED 2
#define SDL_RENDERER_PRESENTVSYNC 4
#define SDL_TEXTUREACCESS_STREAMING 1
#define SDL_PIXELFORMAT_RGBA32 1
#define SDL_HINT_RENDER_SCALE_QUALITY "SDL_RENDER_SCALE_QUALITY"

#define SDLK_UP 1
#define SDLK_DOWN 2
#define SDLK_LEFT 3
#define SDLK_RIGHT 4
#define SDLK_SPACE 5
#define SDLK_LCTRL 6
#define SDLK_LSHIFT 7
#define SDLK_LALT 8
#define SDLK_e 9
#define SDLK_t 10
#define SDLK_TAB 11
#define SDLK_BACKSPACE 12
#define SDLK_RCTRL 13
#define SDLK_RETURN 14
#define SDLK_HOME 15

int SDL_Init(uint32_t flags);
void SDL_Quit(void);
const char *SDL_GetError(void);
int SDL_SetHint(const char *name, const char *value);
SDL_Window *SDL_CreateWindow(const char*, int,int,int,int,uint32_t);
SDL_Renderer *SDL_CreateRenderer(SDL_Window*, int, uint32_t);
SDL_Texture *SDL_CreateTexture(SDL_Renderer*, uint32_t, int, int, int);
void SDL_DestroyTexture(SDL_Texture*);
void SDL_DestroyRenderer(SDL_Renderer*);
void SDL_DestroyWindow(SDL_Window*);
int SDL_PollEvent(SDL_Event*);
int SDL_UpdateTexture(SDL_Texture*, const SDL_Rect*, const void*, int);
int SDL_SetRenderDrawColor(SDL_Renderer*, uint8_t,uint8_t,uint8_t,uint8_t);
int SDL_RenderClear(SDL_Renderer*);
int SDL_RenderCopy(SDL_Renderer*, SDL_Texture*, const SDL_Rect*, const SDL_Rect*);
void SDL_RenderPresent(SDL_Renderer*);
void SDL_Delay(uint32_t);
#endif
