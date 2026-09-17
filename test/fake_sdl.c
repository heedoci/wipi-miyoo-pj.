#include <stdlib.h>
#include <string.h>
#include "SDL2/SDL.h"
struct SDL_Window { int x; };
struct SDL_Renderer { int x; };
struct SDL_Texture { int x; };
static int polls = 0;
int SDL_Init(uint32_t flags) { (void)flags; return 0; }
void SDL_Quit(void) {}
const char *SDL_GetError(void) { return "fake-sdl"; }
int SDL_SetHint(const char *name, const char *value) { (void)name; (void)value; return 1; }
SDL_Window *SDL_CreateWindow(const char*a,int b,int c,int d,int e,uint32_t f){(void)a;(void)b;(void)c;(void)d;(void)e;(void)f;return calloc(1,sizeof(SDL_Window));}
SDL_Renderer *SDL_CreateRenderer(SDL_Window*a,int b,uint32_t c){(void)a;(void)b;(void)c;return calloc(1,sizeof(SDL_Renderer));}
SDL_Texture *SDL_CreateTexture(SDL_Renderer*a,uint32_t b,int c,int d,int e){(void)a;(void)b;(void)c;(void)d;(void)e;return calloc(1,sizeof(SDL_Texture));}
void SDL_DestroyTexture(SDL_Texture*p){free(p);} void SDL_DestroyRenderer(SDL_Renderer*p){free(p);} void SDL_DestroyWindow(SDL_Window*p){free(p);}
int SDL_PollEvent(SDL_Event *e) { if (polls++ == 3) { memset(e,0,sizeof(*e)); e->type=SDL_QUIT; return 1; } return 0; }
int SDL_UpdateTexture(SDL_Texture*a,const SDL_Rect*b,const void*c,int d){(void)a;(void)b;(void)c;(void)d;return 0;}
int SDL_SetRenderDrawColor(SDL_Renderer*a,uint8_t b,uint8_t c,uint8_t d,uint8_t e){(void)a;(void)b;(void)c;(void)d;(void)e;return 0;}
int SDL_RenderClear(SDL_Renderer*a){(void)a;return 0;} int SDL_RenderCopy(SDL_Renderer*a,SDL_Texture*b,const SDL_Rect*c,const SDL_Rect*d){(void)a;(void)b;(void)c;(void)d;return 0;} void SDL_RenderPresent(SDL_Renderer*a){(void)a;} void SDL_Delay(uint32_t a){(void)a;}
