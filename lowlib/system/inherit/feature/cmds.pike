int command_hook(string arg)
{
    string cmd_path;
    object cobj;
    string verb =query_verb();
	// 玩家发空命令（回车 / flushview 内部触发的空 command()）
	// 时 verb 可能是 0，sizeof(0) 会抛 "Bad argument 1 to sizeof"。
	if(!verb || !stringp(verb) || sizeof(verb)==0)
		return 0;
	// 幻境人物本期不开放家园。必须在统一命令分发层拦截全部
	// home_* 旧书签，不能只依赖房间移动守卫，否则远程摆摊/购买命令
	// 仍可能把永恒服资产带入幻境。
	if(search(verb,"home_")==0){
		object seasonal_chard = (object)(ROOT+
			"/gamelib/single/daemons/seasonal_chard.pike");
		if(seasonal_chard && functionp(
		   seasonal_chard->is_active_illusion_character) &&
		   seasonal_chard->is_active_illusion_character(this_object())){
			this_object()->receive("幻境人物本期不开放家园；回归永恒服后即可正常使用。\n");
			return 1;
		}
	}
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
void command(string str,void|object this)
{
	predef::command(str, this);
}
