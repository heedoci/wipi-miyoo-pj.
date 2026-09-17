#ifndef WIPI_MIYOO_EXIT_COMBO_H
#define WIPI_MIYOO_EXIT_COMBO_H

#include <SDL2/SDL.h>

/*
 * OnionOS-style exit combo for the Miyoo Mini Plus.
 *
 * The steward-fu SDL mapping used by this port reports:
 *   MENU   -> SDLK_HOME
 *   SELECT -> SDLK_RCTRL
 *
 * The original frontend treated MENU alone as an immediate exit, while
 * SELECT was used as the temporary numeric-keypad modifier.  Intercept SDL
 * events here so MENU is harmless by itself and MENU+SELECT emits SDL_QUIT.
 * SELECT still reaches the frontend normally when the combo is not active,
 * so the existing keypad modifier keeps working.
 */
static inline int wipi_miyoo_poll_event(SDL_Event *ev) {
    static int menu_down = 0;
    static int select_down = 0;

    while ((SDL_PollEvent)(ev)) {
        if (ev->type != SDL_KEYDOWN && ev->type != SDL_KEYUP) {
            return 1;
        }

        const int down = ev->type == SDL_KEYDOWN;
        const SDL_Keycode sym = ev->key.keysym.sym;

        if (sym == SDLK_HOME) {
            menu_down = down ? 1 : 0;
            if (down && select_down) {
                ev->type = SDL_QUIT;
                return 1;
            }
            /* Suppress MENU itself so the old MENU-alone exit path is never hit. */
            continue;
        }

        if (sym == SDLK_RCTRL) {
            select_down = down ? 1 : 0;
            if (down && menu_down) {
                ev->type = SDL_QUIT;
                return 1;
            }
            /* SELECT alone is still delivered for numeric keypad mode. */
            return 1;
        }

        return 1;
    }

    return 0;
}

#define SDL_PollEvent wipi_miyoo_poll_event

#endif
