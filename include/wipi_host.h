#ifndef WIPI_HOST_H
#define WIPI_HOST_H

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void wipi_init(void);
bool wipi_start(const uint8_t *game_data, size_t game_data_len,
                const char *filename,
                const char *data_dir,
                const char *soundfont_path);
bool wipi_get_frame(uint8_t *out_rgba, size_t capacity);
void wipi_key_down(const char *key);
void wipi_key_up(const char *key);
bool wipi_get_error(char *buf, size_t capacity, uint8_t *out_kind);
void wipi_set_paused(bool paused);
void wipi_set_volume(float pcm_volume, float midi_volume);
bool wipi_poll_exit(void);
void wipi_stop(void);

#ifdef __cplusplus
}
#endif

#endif
