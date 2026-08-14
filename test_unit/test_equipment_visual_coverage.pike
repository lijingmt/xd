#!/usr/bin/env pike
/** 全量基础装备图片覆盖、原创兜底和等级/稀缺度UI接线回归。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = (["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string reason)
{
	test_results["total"]++;
	if(valid){
		test_results["passed"]++;
		werror("  ✓ %s\n",name);
	}
	else{
		test_results["failed"]++;
		werror("  ✗ %s: %s\n",name,reason);
	}
}

string read_picture_name(string source,string fallback)
{
	if(!source)
		return fallback;
	foreach(source/"\n",string line){
		string picture;
		line = String.trim_all_whites(line);
		if(sscanf(line,"picture=\"%s\";",picture)==1)
			return picture;
		if(sscanf(line,"picture = \"%s\";",picture)==1)
			return picture;
	}
	return fallback;
}

int image_exists_in_both_trees(string picture)
{
	foreach(({".gif",".png",".webp",".jpg"}),string extension)
		if(Stdio.file_size(ROOT+"/images/"+picture+extension)>0 &&
		   Stdio.file_size(ROOT+"/web/images/"+picture+extension)>0)
			return 1;
	return 0;
}

int main()
{
	werror("\n========== 装备图片与等级光效覆盖测试 ==========\n");
	array(string) missing = ({});
	int total = 0;
	foreach(({"weapon","armor","jewelry","decorate"}),string kind){
		string root = ROOT+"/gamelib/clone/item/"+kind;
		foreach(get_dir(root) || ({}),string base_name){
			string base_file = root+"/"+base_name+"/"+base_name;
			if(Stdio.file_size(base_file)<=0)
				continue;
			total++;
			string picture = read_picture_name(
				Stdio.read_file(base_file),base_name);
			if(!image_exists_in_both_trees(picture))
				missing += ({kind+"/"+base_name+" -> "+picture});
		}
	}
	// 追赶装备不位于四类历史目录内，也必须具备旧JSP可直接加载的
	// picture 资源；不能只依赖Vue装备面板的部位兜底。
	string catchup_root=ROOT+"/gamelib/clone/item/catchup";
	foreach(get_dir(catchup_root) || ({}),string base_name){
		string base_file=catchup_root+"/"+base_name;
		if(Stdio.file_size(base_file)<=0)
			continue;
		total++;
		string picture=read_picture_name(
			Stdio.read_file(base_file),base_name);
		if(!image_exists_in_both_trees(picture))
			missing += ({"catchup/"+base_name+" -> "+picture});
	}
	check("全部基础装备模型在源码与Web镜像中都有可加载图片",
		total>=303 && !sizeof(missing),
		"total="+total+" missing="+missing*" | ");

	array(string) fallback_slots = ({
		"double_main_weapon","single_main_weapon","single_other_weapon",
		"magic_staff","armor_head","armor_cloth","armor_waste",
		"armor_hand","armor_thou","armor_shoes","jewelry_ring",
		"jewelry_neck","jewelry_bangle","decorate_manteau",
		"decorate_thing","decorate_tool",
	});
	array(string) fallback_missing = ({});
	foreach(fallback_slots,string slot)
		if(Stdio.file_size(ROOT+"/images/equipment/fallback/"+slot+".png")<=0 ||
		   Stdio.file_size(ROOT+"/web/images/equipment/fallback/"+slot+".png")<=0)
			fallback_missing += ({slot});
	check("十六类原创装备兜底图完整且同时进入Tomcat资源树",
		!sizeof(fallback_missing),"缺少："+fallback_missing*",");

	string api = Stdio.read_file(ROOT+
		"/gamelib/single/daemons/_http_api_mod/equipment_panel.pike") || "";
	string app = Stdio.read_file(ROOT+"/vue_source/js/app.js") || "";
	string html = Stdio.read_file(ROOT+"/vue_source/index.html") || "";
	string css = Stdio.read_file(ROOT+"/vue_source/css/app.css") || "";
	string generator = Stdio.read_file(ROOT+
		"/scripts/generate_equipment_image_variants.sh") || "";
	check("装备接口只接受安全图片名并为未来缺图提供部位兜底",
		search(api,"valid_equipment_picture_name")!=-1 &&
		search(api,"search(picture,\"..\")")!=-1 &&
		search(api,"\"image_url\":query_equipment_panel_image")!=-1 &&
		search(api,"/images/equipment/fallback/")!=-1,
		"图片路径校验、存在性探测或兜底字段缺失");
	check("等级与稀缺度独立参与装备光效且头像按八档等级显示",
		search(app,"equipmentRarityClass")!=-1 &&
		search(app,"equipmentLevelClass")!=-1 &&
		search(app,"playerLevelAuraClass")!=-1 &&
		search(html,"equipmentLevelClass(item)")!=-1 &&
		search(css,".equipment-rarity-7")!=-1 &&
		search(css,".equipment-level-5 .equipment-item-art")!=-1 &&
		search(css,".player-avatar-shell.level-aura-7")!=-1,
		"等级、稀缺度或头像等级光效没有独立接线");
	check("补图生成器兼容旧Bash且不会覆盖已有装备美术",
		search(generator,"declare -A")==-1 &&
		search(generator,"if [[ ! -f \"$output\" ]]")!=-1 &&
		search(generator,"magick")!=-1 &&
		search(generator,"web/images")!=-1,
		"生成器可能覆盖老图、依赖Bash4或漏同步Web资源");

	werror("装备视觉覆盖：总计%d，通过%d，失败%d\n",
		test_results["total"],test_results["passed"],
		test_results["failed"]);
	return test_results["failed"]==0 ? 0 : 1;
}
