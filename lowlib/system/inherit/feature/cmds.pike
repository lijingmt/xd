int command_hook(string arg)
{
    string cmd_path;
    object cobj;
    string verb =query_verb();
	object env=environment(this_object());
	array(string) room_cmds=({});
	if(env&&env["query_command_prefix"]){
		room_cmds=env->query_command_prefix();
	}
   	array(string) a=room_cmds+this_object()->query_command_prefix();
	array(string) posible=({});
	string perfect;
    	for(int i=0;i<sizeof(a);i++){
		cmd_path = a[i]+"/";
		array(string) d=get_dir(cmd_path);
		if(d){
			foreach(d,string s){
				if(s[0..sizeof(verb)-1]==verb&&s[-1]!='~'){
					posible+=({a[i]+"/"+s});
					if(!perfect&&(s==verb||s==verb+".pike")){
						perfect=a[i]+"/"+s;
					}
				}
			}
		}
	}
	if(sizeof(posible)==1){
		cmd_path=posible[0];
		cobj = load_object(cmd_path);
		if (cobj) {
			return (int)cobj->main(arg);
		}
	}
	else if(perfect){
		cobj = load_object(perfect);
		if (cobj) {
			return (int)cobj->main(arg);
		}
	}
	return 0;
}
void command(string str)
{
	predef::command(str);
}
