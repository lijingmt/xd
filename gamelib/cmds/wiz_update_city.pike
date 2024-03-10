#include <command.h>
#include <gamelib/include/gamelib.h>
//后台手动更新城池占有情况的指令
//arg = city race
int main(string arg)
{
	string city_name="";
	string race="";
	sscanf(arg,"%s %s",city_name,race);
	if(city_name == "xiqicheng" || city_name == "chaogecheng"){
		if(race == "human" || race == "monst")
			if(CITYD->capture_city(city_name,race,""))
				write(city_name+" be caputred by "+race+" suc!\n");
			else
				write(city_name+" be caputred by "+race+" wrong!\n");
		else
			write(race+" is not permitted!\n");
	}
	else
		write(city_name+" is not permitted\n");
	return 1;
}
