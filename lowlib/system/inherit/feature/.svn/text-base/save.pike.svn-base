#include <globals.h>
static object SQL;
static string TABLE;
array(string) inventory;
array(string) inventory_data;
object load_player(string _name)
{
	object ob=find_player(_name);
	if(ob&&object_program(ob)==object_program(this_object())){
		//werror("found!");
		return ob;
	}
	ob=object_program(this_object())();
	ob->name=_name;
	ob->project=this_object()->project;
	if(ob->restore()){
		//werror("restore ok!");
		return ob;
	}
	else{
		werror("restore fail!");
	}
	return 0;
}
int restore()
{
//	return sql_restore_object(USERD->db,TABLE,query_name());
	string name=this_object()->query_name();
	int succ;
	if(SQL==0||TABLE==0||TABLE==""){
		string dir="u";
		if(TABLE!=0&&TABLE!=""){
			dir=TABLE;
		}
		//succ=restore_object(ROOT+"/"+this_object()->query_project()+"/"+dir+"/"+name[sizeof(name)-2..]+"/"+name+".o");
		//尝试用统一的用户目录/usr/local/games/usrdata0/
		//werror("\n====system/inherit/feature/save.pike->call restore.pike ====\n");
		succ=restore_object(DATA_ROOT+"u/"+name[sizeof(name)-2..]+"/"+name+".o");
	}
	else{
		succ=sql_restore_object(SQL,TABLE,name);
	}
	foreach(all_inventory(),object ob){
		ob->remove();
	}
	if(inventory){
		for(int i=0;i<sizeof(inventory);i++){
			string filename=inventory[i];
			if(filename=="0") continue;
			
			if((filename/"/gamelib")[0] != "~")
				filename = "~/gamelib"+(filename/"/gamelib")[1];
			object ob=clone(expand_symlinks(pikenv_path(filename)));
			if(ob){
				if(inventory_data&&i<sizeof(inventory_data)){
					pikenv_restore_object(ob,inventory_data[i]);
				}
				ob->move(this_object());
			}
		}
		inventory=0;
	}
	return succ;
}
int save()
{
//	return sql_save_object(USERD->db,TABLE,query_name());
	string name=this_object()->query_name();
	inventory=({});
	inventory_data=({});
	foreach(all_inventory(),object ob){
		if(ob->query_item_save()){
			string file;
			string s=file=file_name(ob);
			sscanf(file,"%s#%*d",s);
			inventory+=({pikenv_relative_path(s)});
			inventory_data+=({pikenv_save_object(ob)});
		}
	}
	if(name&&sizeof(name)){
		if(SQL==0||TABLE==0||TABLE==""){
			string dir="u";
			if(TABLE!=0&&TABLE!=""){
				dir=TABLE;
			}
			//尝试用统一的用户目录/usr/local/games/usrdata0/
			mkdir(DATA_ROOT+"u/"+name[sizeof(name)-2..]);
			return save_object(DATA_ROOT+"u/"+name[sizeof(name)-2..]+"/"+name+".o");
			//mkdir(ROOT+"/"+this_object()->query_project()+"/"+dir+"/"+name[sizeof(name)-2..]);
			//return save_object(ROOT+"/"+this_object()->query_project()+"/"+dir+"/"+name[sizeof(name)-2..]+"/"+name+".o");
		}
		else{
			return sql_save_object(SQL,TABLE,name);
		}
	}
	return 0;
}

