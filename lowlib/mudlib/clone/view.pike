#include <globals.h>
#include <mudlib/include/mudlib.h>

string template;
/*
look:
   	$(env->query_name_cn()) -\n$(env->have_item())\n$(env->have_character())\n$(env->query_exits()\n$(env->query_desc())\n
	$(ob->name_cn()) -\n$(arg)
	$E -\n$i\n$c\n$e$D
*/

private object viewer;
int cacheable;

void create(string s,void|int _cacheable)
{
	template=s;
	cacheable=_cacheable;
}
string `()(void|object ob,void|object player,void|mixed arg)
{
	if(player==0){
		player=this_player();
	}
	if(!viewer){
		string code=
			"string view(void|object ob,void|object player,void|mixed arg){\n"
			"object env=environment(player);\nstring out=\"\";mixed err;";
		for(int i=0;i<sizeof(template);){
			if(template[i]=='$'){
				if(i<sizeof(template)-1&&template[i+1]=='('){
					i+=2;
					string s="";
					int quot_count=1;
					while(i<sizeof(template)){
						if(template[i]==')'){
							quot_count--;
							if(quot_count==0)
								break;
						}
						else if(template[i]=='('){
							quot_count++;
						}
						s+=template[i..i];
						i++;
					}
					code+="err=catch{out+=("+s+");};\n\nif(err){werror("+pikenv_encode_value(pikenv_encode_value(s))+"+\"\\n\");}\n\n";
				}
				i++;
			}
			else{
				string d="";
				while(i<sizeof(template)&&template[i]!='$'){
					d+=template[i..i];
					i++;
				}
				code+="out+="+pikenv_encode_value(d)+";\n";
			}
		}
		code+="return out;}\n";
		program p=compile(code);
		viewer=p();
	}
	return viewer->view(ob,player,arg);
}
