#include <globals.h>
protected object SQL;
protected string TABLE;
array(string) inventory;
array(string) inventory_data;

protected string atomic_save_name()
{
	string name = "";
	mixed err = catch{
		name = this_object()->query_name();
	};
	if(err || !name)
		name = "unknown";
	return name;
}

protected void atomic_save_log(string msg)
{
	string now = ctime(time());
	Stdio.append_file(ROOT+"/log/atomic_save.log",
		now[0..sizeof(now)-2]+" [ATOMIC_SAVE] ["+
		atomic_save_name()+"] "+msg+"\n");
}

protected void atomic_save_error(string msg)
{
	atomic_save_log(msg);
	werror("[ATOMIC_SAVE] "+msg+"\n");
}

protected int atomic_save(string filepath,string temppath)
{
	string basedir;
	string backuppath;
	string backuptemppath;
	int ok;
	int live_size;
	int tmp_size;
	int backup_size;
	mixed err;
	if(!filepath || !temppath){
		atomic_save_error("invalid filepath or temppath");
		return 0;
	}
	basedir = dirname(filepath);
	backuppath = filepath+".bak";
	backuptemppath = filepath+".bak.tmp";
	ok = 0;
	live_size = 0;
	tmp_size = 0;
	backup_size = 0;
	if(basedir && basedir!="/")
		mkdir(basedir);
	err = catch{
		rm(temppath);
		rm(backuptemppath);
		if(!save_object(temppath))
			atomic_save_error("write temp failed filepath="+filepath);
		else{
			tmp_size = Stdio.file_size(temppath);
			if(tmp_size<=0)
				atomic_save_error("temp file empty filepath="+filepath);
			else{
				live_size = Stdio.file_size(filepath);
				if(live_size>0){
					mixed backup_err = catch{
						Stdio.cp(filepath,backuptemppath);
					};
					backup_size = Stdio.file_size(backuptemppath);
					if(backup_err || backup_size!=live_size)
						atomic_save_error("backup failed filepath="+filepath);
					else if(!mv(backuptemppath,backuppath))
						atomic_save_error("backup rename failed filepath="+filepath);
					else if(!mv(temppath,filepath))
						atomic_save_error("replace failed filepath="+filepath);
					else if(Stdio.file_size(filepath)<=0)
						atomic_save_error("saved file empty filepath="+filepath);
					else
						ok = 1;
				}
				else if(!mv(temppath,filepath))
					atomic_save_error("initial replace failed filepath="+filepath);
				else if(Stdio.file_size(filepath)<=0)
					atomic_save_error("initial saved file empty filepath="+filepath);
				else
					ok = 1;
			}
		}
	};
	if(err){
		atomic_save_error("exception during save filepath="+filepath+
			" error="+describe_backtrace(err));
		rm(temppath);
		rm(backuptemppath);
		return 0;
	}
	if(!ok){
		rm(temppath);
		rm(backuptemppath);
		return 0;
	}
	return 1;
}
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
		string filepath = DATA_ROOT+"u/"+name[sizeof(name)-2..]+
			"/"+name+".o";
		string backuppath = filepath+".bak";
		string temppath = filepath+".tmp";
		if(Stdio.file_size(filepath)<=0 &&
		   Stdio.file_size(backuppath)>0){
			atomic_save_log("restore backup filepath="+filepath);
			succ=restore_object(backuppath);
		}
		else if(Stdio.file_size(filepath)<=0 &&
			Stdio.file_size(temppath)>0){
			atomic_save_log("restore temp filepath="+filepath);
			succ=restore_object(temppath);
		}
		else
			succ=restore_object(filepath);
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
			// pikenv_path already returns absolute path, no need for expand_symlinks
			string final_path=pikenv_path(filename);
			Stdio.append_file("/tmp/xiand_login_debug.log", sprintf("inventory[%d]: orig=%s\n  after_check=%s\n  final_path=%s\n",
				i, inventory[i], filename, final_path));
			// Use catch to handle missing items gracefully
			mixed err = catch {
				object ob=clone(final_path);
				if(ob){
					if(inventory_data&&i<sizeof(inventory_data)){
						pikenv_restore_object(ob,inventory_data[i]);
					}
					ob->move(this_object());
				}
			};
			if(err){
				Stdio.append_file("/tmp/xiand_login_debug.log", "clone failed for: "+final_path+" - "+sprintf("%O", err[0])+"\n");
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
			string filepath = DATA_ROOT+"u/"+name[sizeof(name)-2..]+
				"/"+name+".o";
			string temppath = filepath+".tmp";
			mkdir(DATA_ROOT+"u/"+name[sizeof(name)-2..]);
			return atomic_save(filepath,temppath);
			//mkdir(ROOT+"/"+this_object()->query_project()+"/"+dir+"/"+name[sizeof(name)-2..]);
			//return save_object(ROOT+"/"+this_object()->query_project()+"/"+dir+"/"+name[sizeof(name)-2..]+"/"+name+".o");
		}
		else{
			return sql_save_object(SQL,TABLE,name);
		}
	}
	return 0;
}
