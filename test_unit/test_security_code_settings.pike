#!/usr/bin/env pike
/** 安全码入口归位测试：主场景去除入口、设置页按绑定状态显示。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

int main()
{
	array(string) compile_paths = ({
		"/gamelib/cmds/game_detail.pike",
		"/gamelib/cmds/bandpsw_readme.pike",
		"/gamelib/cmds/set_bandpsw.pike",
		"/gamelib/cmds/set_bandpsw_confirm.pike",
		"/gamelib/cmds/bandpsw_change.pike",
		"/gamelib/cmds/bandpsw_change_confirm.pike",
		"/lowlib/wapmud2/single/viewd.pike",
	});
	string view_source = Stdio.read_file(
		ROOT+"/lowlib/wapmud2/single/viewd.pike");
	string settings_source = Stdio.read_file(
		ROOT+"/gamelib/cmds/game_detail.pike");
	string readme_source = Stdio.read_file(
		ROOT+"/gamelib/cmds/bandpsw_readme.pike");
	int failed = 0;
	string error_desc = "";

	foreach(compile_paths,string path){
		mixed err = catch {
			program compiled = (program)(ROOT+path);
			if(!compiled)
				failed++;
		};
		if(err){
			failed++;
			error_desc += path+": "+describe_error(err);
		}
	}
	if(!view_source || search(view_source,"query_bandpswd_link()")!=-1)
		failed++;
	if(!settings_source ||
	   search(settings_source,"[绑定安全码:set_bandpsw]")==-1 ||
	   search(settings_source,"[修改安全码:bandpsw_change]")==-1 ||
	   search(settings_source,"[安全码说明:bandpsw_readme]")==-1 ||
	   search(settings_source,"me->bandpswd && sizeof(me->bandpswd)")==-1)
		failed++;
	if(!readme_source ||
	   search(readme_source,"[返回设置:game_detail]")==-1)
		failed++;
	if(failed){
		werror("安全码设置入口测试失败(%d): %s\n",failed,error_desc);
		return 1;
	}
	werror("安全码设置入口测试通过。\n");
	return 0;
}
