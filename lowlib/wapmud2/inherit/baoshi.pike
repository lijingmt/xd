#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_F_EQUIP;
inherit MUD_COMBINE_ITEM;
inherit WAP_F_VIEW_PICTURE;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;

private string initer=((set_item_type("baoshi")),"");

//��ʯ��ɫ
private string color = "";
void set_color(string s){ color = s;}
string query_color(){ return color;}

string query_color_cn(string color){
	string s = "";
	switch(color){
		case "blue": s += "��ɫ";
			     break;
		case "red": s += "��ɫ";
			     break;
		case "yellow": s += "��ɫ";
			     break;
	}
	return s;
}
