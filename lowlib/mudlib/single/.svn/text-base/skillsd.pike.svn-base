#include <globals.h>
#include <mudlib/include/mudlib.h>
inherit LOW_DAEMON;
private mapping(string:object) skills=([]);
private array(object) unmapped=({});
void add_skill(object ob)
{
	unmapped+=({ob});
}
object`[](mixed key)
{
	if(unmapped&&sizeof(unmapped)){
		foreach(unmapped,object ob){
			if(skills[ob->name]){
				werror("same skill defined twice: "+ob->name+"\n");
			}
			else{
				skills[ob->name]=ob;
			}
		}
		unmapped=({});
	}
	return skills[key];
}
