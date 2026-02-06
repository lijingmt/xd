#!/usr/local/bin/pike -dt
#include "lowlib.h"
#define PORT 9999
#define IP "0.0.0.0"
Stdio.Port port;
object lib_master;
void create()
{
	port=Stdio.Port();
}
void accept_callback()
{
	Stdio.File ob=port->accept();
	if(!ob)
		return;
	program u=lib_master->connect();
	CONN(ob,u());
} 

object efuns;
class pikenv_master{
	inherit "/master";
	//mapping(string:object) saved_objects;
	/*
	program cast_to_program(string pname, string current_file, object|void handler){
		//werror("program cast_to_program(pname="+pname+")    begin\n");
		//werror("program cast_to_program(current="+current_file+")    begin\n");
		program pr;
		mixed err;
		err=catch{
			pr=::cast_to_program(pname,current_file,handler);
		};
		if(!err&&pr)
			return pr;
		err=catch{
			pr=decode_value(Stdio.read_file(pname),Codec());
			programs[pname]=pr;
		};
		if(!err&&pr)
			return pr;
		foreach(indices(master()->programs),string s){
			if(master()->programs[s]==0)
				m_delete(master()->programs,s);
		}
		return pr;
	}
	program pikenv_cast_to_program(string pname, string current_file, object|void handler){
		program pr;
		mixed err=catch{
			pr=cast_to_program(pname,current_file,handler);
		};
		if(!err&&pr)
			return pr;
		else if(err){
			handle_error(err,"WARNING");
			//werror("\n\npikenv_cast_to_program->cast_to_program fail!!\n\n");
		}
		string d=Stdio.read_file(pname);
		string path;
		sscanf(d,"#%s\n",path);
		path=efuns->pikenv_path(path);
		pr=cast_to_program(path,current_file);
		if(pr){
			//werror("cast_to_program:1 "+pname+"\n");
			//programs[pname]=pr;
		}
		else{
			//handle_error(err);
			throw(err);
		}
		return pr;
	}
	object cast_to_object(string oname, string current_file){
		//werror("program cast_to_object(oname="+oname+")    begin\n");
		//werror("program cast_to_object(current="+current_file+")    begin\n");
		//werror("cast_to_object(string oname = "+oname+", string cur_file = "+current_file+"\n");
		if(oname[0]=='/'){
			oname=combine_path("/",oname);
		}
		else{
			string cwd;
			if(current_file)
				cwd=dirname(current_file);
			else
				cwd=getcwd();
			oname=combine_path(cwd,oname);
		}
		if(saved_objects[oname])
			return saved_objects[oname];
		//werror("cast_to_object:0 "+oname+"\n");
		object ob;
		mixed err=catch{
			ob=::cast_to_object(oname,current_file);
		};
		if(!err&&ob)
			return ob;
		else if(err)
			handle_error(err,"WARNING");
		program pr;
		mixed err1=catch{
			pr=pikenv_cast_to_program(oname, current_file);
		};
		if(!err1&&pr){
			ob=pr();
			//werror("cast_to_object:1 "+oname+"\n");
			efuns->restore_object(oname,0,ob);
			saved_objects[oname]=ob;
//			objects[pr]=ob;
		}
		else if(err){
//			handle_error(err);
			throw(err);
		}
		return ob;
	}
	void handle_error(array(mixed)|object trace,void|string header)
	{
		if(header==0)
			header="ERROR";
		if(mixed x=catch {
				//werror("\n-----"+String.trim_all_whites(ctime(time()))+"-----\n"+header+": *"+describe_backtrace(trace));
//				log->write(ctime(time())+":"+describe_backtrace(trace));
				}) {
			// One reason for this might be too little stack space, which
			// easily can occur for "out of stack" errors. It should help to
			// tune up the STACK_MARGIN values in interpret.c then.
			//werror("Error in handle_error in master object:\n");
			if(catch {
					catch {
					if (catch {
						string msg = [string]x[0];
						array bt = [array]x[1];
						//werror("%s%O\n", msg, bt);
						log->write("%s%O\n", msg, bt);
						}) {
					//werror("%O\n", x);
//					log->write("%O\n", x);
					}
					};
					//werror("Original error:\n"
						//"%O\n", trace);
//					log->write("Original error:\n"
//						"%O\n", trace);
					}) {
				//werror("sprintf() failed to write error.\n");
			}
		}
	}
	*/
	Stdio.File log;
	void create(string ROOT,string postfix)
	{
		Stdio.mkdirhier(ROOT+"/log");
		log=Stdio.File(ROOT+"/log/error."+postfix,"wca");
		log->dup2(Stdio.stderr);
		/* You need to copy the values from the old master to the new */
		/* NOTE: At this point we are still using the old master */
		object old_master = master();
		object new_master = this_object();
		foreach(indices(old_master), string varname){
			/* The catch is needed since we can't assign constants */            
			catch{new_master[varname] = old_master[varname];};
		}
		//saved_objects=set_weak_flag(([]),Pike.WEAK_VALUES);
	}
};
int main(int argc, array(string) argv)
{
	Process.system("cd "+dirname(argv[0])+";make 2>/dev/null >/dev/null");
	array a=Getopt.find_all_options(argv,({
				({"port",Getopt.HAS_ARG,({"-p","--port"})})
				,({"ip",Getopt.HAS_ARG,({"-i","--ip"})})
				,}));
	mapping opts=mkmapping(column(a,0),column(a,1));
	array(string) args=Getopt.get_args(argv);
	string root=dirname(argv[0]);
	string mudlib_root=combine_path(getcwd(),args[1]);
	while(mudlib_root[sizeof(mudlib_root)-1]=='/'){
		mudlib_root=mudlib_root[0..(sizeof(mudlib_root)-2)];
	}
	string master;
	if(opts["master"]){
		master=combine_path(mudlib_root,opts["master"]);
	}
	else{
		master=combine_path(root,"system/master");
	}
	if(Stdio.is_dir(mudlib_root)){
		Stdio.recursive_rm(mudlib_root+"/.include");
		mkdir(mudlib_root+"/.include");
		Stdio.write_file(mudlib_root+"/.include/sys_config.h","#define SROOT \""+root+"\"\n#define ROOT \""+mudlib_root+"\"");
		foreach(get_dir(root),string s){
			if(Stdio.is_dir(root+"/"+s)&&Stdio.is_file(root+"/"+s+"/include/"+s+".h")){
				Stdio.write_file(mudlib_root+"/.include/"+s+".h","#include <"+root+"/"+s+"/include/"+s+".h>");
			}
		}
		foreach(get_dir(mudlib_root),string s){
			if(Stdio.is_dir(mudlib_root+"/"+s)&&Stdio.is_file(mudlib_root+"/"+s+"/include/"+s+".h")){
				Stdio.write_file(mudlib_root+"/.include/"+s+".h","#include <"+mudlib_root+"/"+s+"/include/"+s+".h>");
			}
		}
	}
	add_include_path(root);
	add_include_path(mudlib_root);
	add_include_path(mudlib_root+"/.include");
	add_include_path(root+"/system/include");
	add_program_path(root);
	efuns=(object)(root+"/efuns.pike");
	efuns->ROOT=mudlib_root+"/";
	efuns->logfile_postfix=opts["port"]?(opts["port"]):(string)(PORT);
	replace_master(pikenv_master(mudlib_root,opts["port"]?(opts["port"]):(string)(PORT)));
	lib_master=((object)master);
	object ob;
	int retval=-1;
	string ip_str,port_str;
	if(sizeof(lib_master->hosts_list)&&sscanf(lib_master->hosts_list[0],"%s:%s",ip_str,port_str)==2){
	}
	else{
		//werror("No valid hosts_list,use default.\n");
		ip_str=IP;
		port_str=PORT+"";
	}
	lib_master->ip=opts["ip"]?opts["ip"]:ip_str;
	lib_master->port=opts["port"]?(int)(opts["port"]):(int)port_str;
	if(!port->bind(lib_master->port, accept_callback,lib_master->ip)){
		//werror("Failed to open socket (already bound?)\n");
		return port->errno();
	}
	return retval;
}
