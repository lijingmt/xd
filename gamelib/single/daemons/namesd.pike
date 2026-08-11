//管理注册用户中文名的程序
//
//核心数据结构:
//1.已注册用户名: array names_regged
//2.限制用户名:array names_reserved
//
//上述结构通过读取ROOT/gamelib/etc/regname和reserved_names两个文件。
//
//由liaocheng于08/06/02开始设计开发

#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define REGNAME ROOT "/gamelib/etc/regname" //已注册用户名文件
#define RESERVED_NAMES ROOT "/gamelib/etc/reserved_names" //已注册用户名文件
#define REGNAME_PROFILE_LOCK DATA_ROOT "regname.profile.lock"

private array names_regged = ({});
private array names_reserved = ({});
private Thread.Mutex profile_name_lock = Thread.Mutex();
private mapping(string:string) profile_name_reservations = ([]);
private mapping(string:int) profile_name_release_retries = ([]);

protected void create()
{
	names_regged = ({});
	names_reserved = ({});
	load_infos();
}

void load_infos()
{
	string regData = Stdio.read_file(REGNAME);
	array(string) lines = regData/"\n";
	if(lines && sizeof(lines)){
		names_regged = lines-({""});
	}
	else 
		werror("------null in regname------\n");
	string reservData = Stdio.read_file(RESERVED_NAMES);
	lines = reservData/"\n";
	if(lines && sizeof(lines)){
		names_reserved = lines-({""});
	}
	else 
		werror("------null in reserved_names------\n");
	return;
}

private string canonical_profile_name(string name)
{
	string canonical;
	if(!name)
		return "";
	name = String.trim_all_whites(name);
	if(name=="")
		return "";
	canonical = String.width(name)>8 ? string_to_utf8(name) : name;
	mixed decode_err = catch { utf8_to_string(canonical); };
	return decode_err ? "" : canonical;
}

/**
 * Vue/API 与旧人物资料补全共用的名字规则。
 * 返回的 name 始终是游戏存档历史沿用的 UTF-8 字节串。
 */
mapping(string:mixed) validate_profile_name(string name)
{
	string canonical = canonical_profile_name(name);
	string decoded;
	int visual_units = 0;
	array(string) forbidden = ({
		"管理员","客服","系统","官方","管理","游戏","运营",
		"gm","root","admin",
	});
	if(canonical=="")
		return (["ok":0,"message":"请输入有效的人物姓名。"]);
	decoded = utf8_to_string(canonical);
	if(sizeof(decoded)<2)
		return (["ok":0,"message":"人物姓名至少需要2个字符。"]);
	foreach(decoded;int index;int codepoint){
		if((codepoint>='a' && codepoint<='z') ||
		   (codepoint>='A' && codepoint<='Z') ||
		   (codepoint>='0' && codepoint<='9'))
			visual_units++;
		else if((codepoint>=0x3400 && codepoint<=0x4dbf) ||
		        (codepoint>=0x4e00 && codepoint<=0x9fff) ||
		        (codepoint>=0xf900 && codepoint<=0xfaff))
			visual_units += 2;
		else
			return (["ok":0,
				"message":"人物姓名只能包含中文、英文字母或数字。"]);
	}
	if(visual_units>12)
		return (["ok":0,"message":"人物姓名最多6个中文或12个英文字符。"]);
	if(has_prefix(canonical,"无名"))
		return (["ok":0,"message":"请取一个不以“无名”开头的姓名。"]);
	string lowered = lower_case(canonical);
	foreach(forbidden,string word){
		if(search(lowered,lower_case(word))!=-1)
			return (["ok":0,"message":"姓名包含不允许使用的词语。"]);
	}
	if(is_name_reserved(canonical))
		return (["ok":0,"message":"这个姓名不能使用，请重新选择。"]);
	return (["ok":1,"message":"","name":canonical]);
}

private mapping(string:object)|zero acquire_profile_file_lock()
{
	object file = Stdio.File();
	object file_key;
	if(!file->open(REGNAME_PROFILE_LOCK,"wca"))
		return 0;
	mixed lock_err = catch { file_key = file->lock(); };
	if(lock_err || !file_key){
		file->close();
		return 0;
	}
	return (["file":file,"key":file_key]);
}

private void release_profile_file_lock(mapping(string:object)|zero lock_data)
{
	if(!lock_data)
		return;
	if(lock_data["key"])
		destruct(lock_data["key"]);
	if(lock_data["file"])
		lock_data["file"]->close();
}

private void reload_regged_unlocked()
{
	string data = Stdio.read_file(REGNAME) || "";
	names_regged = (data/"\n")-({""});
}

private int rewrite_regged_unlocked(array(string) names)
{
	string temp_path = REGNAME+".profile.tmp."+
		String.string2hex(Crypto.Random.random_string(6));
	string encoded = sizeof(names) ? names*"\n"+"\n" : "";
	int ok = Stdio.write_file(temp_path,encoded)==sizeof(encoded) &&
		Stdio.file_size(temp_path)==sizeof(encoded) &&
		mv(temp_path,REGNAME);
	if(!ok)
		rm(temp_path);
	return ok;
}

/** 跨线程、跨 Worker 进程占用一个新姓名。成功后必须 commit 或 release。 */
mapping(string:mixed) reserve_profile_name(string name)
{
	mapping validation = validate_profile_name(name);
	mapping(string:object)|zero file_lock;
	object key;
	string canonical;
	string token;
	if(!(int)validation["ok"])
		return validation;
	canonical = (string)validation["name"];
	key = profile_name_lock->lock();
	file_lock = acquire_profile_file_lock();
	if(!file_lock){
		destruct(key);
		return (["ok":0,"message":"姓名服务暂时繁忙，请稍后重试。"]);
	}
	reload_regged_unlocked();
	if(has_value(names_regged,canonical)){
		release_profile_file_lock(file_lock);
		destruct(key);
		return (["ok":0,"message":"这个姓名已经有人使用了。"]);
	}
	if(Stdio.append_file(REGNAME,canonical+"\n")<=0){
		release_profile_file_lock(file_lock);
		destruct(key);
		return (["ok":0,"message":"姓名登记失败，请稍后重试。"]);
	}
	names_regged += ({canonical});
	token = String.string2hex(Crypto.Random.random_string(16));
	profile_name_reservations[canonical] = token;
	release_profile_file_lock(file_lock);
	destruct(key);
	return (["ok":1,"message":"","name":canonical,"token":token]);
}

void commit_profile_name(string name,string token)
{
	object key = profile_name_lock->lock();
	if(profile_name_reservations[name]==token){
		m_delete(profile_name_reservations,name);
		m_delete(profile_name_release_retries,name);
	}
	destruct(key);
}

void release_profile_name(string name,string token)
{
	object key = profile_name_lock->lock();
	mapping(string:object)|zero file_lock;
	int released = 0;
	if(profile_name_reservations[name]!=token){
		destruct(key);
		return;
	}
	file_lock = acquire_profile_file_lock();
	if(file_lock){
		reload_regged_unlocked();
		int remove_at = -1;
		for(int index=sizeof(names_regged)-1;index>=0;index--){
			if(names_regged[index]==name){
				remove_at = index;
				break;
			}
		}
		if(remove_at!=-1){
			array(string) updated = ({});
			if(remove_at>0)
				updated += names_regged[..remove_at-1];
			if(remove_at+1<sizeof(names_regged))
				updated += names_regged[remove_at+1..];
			if(rewrite_regged_unlocked(updated)){
				names_regged = updated;
				released = 1;
			}
		}
		else
			released = 1;
		release_profile_file_lock(file_lock);
	}
	if(released){
		m_delete(profile_name_reservations,name);
		m_delete(profile_name_release_retries,name);
	}
	else{
		int retries = profile_name_release_retries[name]+1;
		profile_name_release_retries[name] = retries;
		if(retries<=3)
			call_out(release_profile_name,1,name,token);
		else
			werror("[NAMESD] 姓名回滚失败，保留占用以防重名: %s\n",name);
	}
	destruct(key);
}

// TestUnit 专用：测试姓名以 testunit 开头时可清理，绝不开放普通姓名删除。
void remove_test_profile_name(string name)
{
	string canonical = canonical_profile_name(name);
	object key;
	mapping(string:object)|zero file_lock;
	if(!getenv("XIAND_RUN_TESTUNIT") || !has_prefix(canonical,"testunit"))
		return;
	key = profile_name_lock->lock();
	file_lock = acquire_profile_file_lock();
	if(file_lock){
		reload_regged_unlocked();
		array(string) updated = names_regged-({canonical});
		if(sizeof(updated)!=sizeof(names_regged) &&
		   rewrite_regged_unlocked(updated))
			names_regged = updated;
		release_profile_file_lock(file_lock);
	}
	m_delete(profile_name_reservations,canonical);
	m_delete(profile_name_release_retries,canonical);
	destruct(key);
}

//判断是否名字是受限制的
//返回1-受限 0-通过
int is_name_reserved(string name)
{
	foreach(names_reserved,string name_tmp){
		if(name_tmp == name)
			return 1;
	}
	return 0;
}

//判断是否名字已被注册
//返回1-已注册 0-未注册
int is_name_regged(string name)
{
	// 姓名文件锁不可用时失败关闭，不能把“查不到”误当成“可注册”。
	int found = 1;
	object key = profile_name_lock->lock();
	mapping(string:object)|zero file_lock = acquire_profile_file_lock();
	if(file_lock){
		reload_regged_unlocked();
		found = has_value(names_regged,name);
		release_profile_file_lock(file_lock);
	}
	destruct(key);
	return found;
}

//取名字后，记录该名字
void reg_name(string name)
{
	if(name && name != ""){
		object key = profile_name_lock->lock();
		mapping(string:object)|zero file_lock = acquire_profile_file_lock();
		if(file_lock){
			reload_regged_unlocked();
			if(!has_value(names_regged,name) &&
			   Stdio.append_file(REGNAME,name+"\n")>0)
				names_regged += ({name});
			release_profile_file_lock(file_lock);
		}
		destruct(key);
	}
	return;
}

//判断输入的字符串是否只包含字母和数字 
//0 否 ; 1 是
//add by caijie 080812
int is_psw(string psw)
{
	for(int i=0;i<sizeof(psw);i++){
		if(psw[i]>='a'&&psw[i]<='z'||psw[i]>='A'&&psw[i]<='Z'||psw[i]>='0'&&psw[i]<='9'){
			return 1;
		}
		else 
			return 0;
	}
}
