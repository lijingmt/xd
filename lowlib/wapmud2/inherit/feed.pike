#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_COMBINE_ITEM;
inherit WAP_F_VIEW_PICTURE;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;

//饲料增加的生命
int life_add;
void set_life_add(int value){life_add=value;}
int query_life_add(){return life_add;}

int str_add;
void set_str_add(int value){str_add=value;}
int query_str_add(){return str_add;}

int think_add;
void set_think_add(int value){think_add=value;}
int query_think_add(){return think_add;}

int dex_add;
void set_dex_add(int value){dex_add=value;}
int query_dex_add(){return dex_add;}
