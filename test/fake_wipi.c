#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include "wipi_host.h"
static int frames=0;
void wipi_init(void) {}
bool wipi_start(const uint8_t*a,size_t b,const char*c,const char*d,const char*e){(void)a;(void)b;(void)c;(void)d;(void)e;return true;}
bool wipi_get_frame(uint8_t*out,size_t cap){if(frames++==0 && cap>=240*320*4){memset(out,0,240*320*4);return true;}return false;}
void wipi_key_down(const char*k){(void)k;} void wipi_key_up(const char*k){(void)k;}
bool wipi_get_error(char*b,size_t c,uint8_t*k){(void)b;(void)c;(void)k;return false;}
void wipi_set_paused(bool p){(void)p;} void wipi_set_volume(float a,float b){(void)a;(void)b;} bool wipi_poll_exit(void){return false;} void wipi_stop(void){}
