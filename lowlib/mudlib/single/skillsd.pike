#include <globals.h>
#include <mudlib/include/mudlib.h>
inherit LOW_DAEMON;
private mapping(string:object) skills=([]);
private array(object) unmapped=({});
void add_skill(object ob)
{
	unmapped+=({ob});
}
private void flush_unmapped_skills()
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

}
protected object`[](mixed key)
{
	flush_unmapped_skills();
	return skills[key];
}

mapping query_cache_status()
{
	flush_unmapped_skills();
	return ([
		"mode":"resident_object_index",
		"skills":sizeof(skills),
		"pending":sizeof(unmapped),
	]);
}
