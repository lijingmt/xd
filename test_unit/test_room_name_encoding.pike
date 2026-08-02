#!/usr/bin/env pike
/**
 * 历史地图房间名编码回归测试。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:string) expected_room_names = ([
	"gamelib/d/yandigu/xiaoshilu":"小石路",
	"gamelib/d/yandigu/taixianshilu":"苔藓石路",
	"gamelib/d/fuxishan/yingshilu":"硬石路",
	"gamelib/d/nanhai/taixianlu":"苔藓路",
	"gamelib/d/jadhuanjingwaicheng/qiantan":"浅滩",
	"gamelib/d/klshuanjingwaicheng/mangyuan":"莽原",
	"gamelib/d/kunlunshan/mangyuan":"莽原",
	"gamelib/d/xiqiwaicheng/sanshaxiaolu":"散沙小路",
	"gamelib/d/chaogewaicheng/liaotai":"鹿台",
	"gamelib/d/donghai/taquanxiaolu":"踏泉小路",
	"gamelib/d/liuguangpingyuan/yaoxuexiaolu":"耀雪小路",
	"gamelib/d/liuguangpingyuan/xueranxiaolu":"雪然小路",
	"gamelib/d/liangjinghu/nuanshuitan":"暖水滩",
	"gamelib/d/huangyuan/yingxielu":"映血路",
]);

int main()
{
	int failed = 0;

	werror("\n========================================\n");
	werror("历史地图房间名编码回归测试\n");
	werror("========================================\n");

	foreach(expected_room_names;string room_path;string expected_name){
		string source = Stdio.read_file(ROOT+"/"+room_path);
		program|zero room_program = 0;
		mixed err = catch {
			utf8_to_string(source);
			room_program = (program)(ROOT+"/"+room_path);
		};
		if(!err && room_program && source &&
		   search(source,"name_cn")!=-1 &&
		   search(source,"\""+expected_name+"\"")!=-1){
			werror("  ✓ %s：%s\n",room_path,expected_name);
		}
		else{
			failed++;
			werror("  ✗ %s：应为%s，且源码必须是有效UTF-8并可编译%s\n",
				room_path,expected_name,
				err ? "（"+describe_error(err)+"）" : "");
		}
	}

	werror("[房间名编码] complete failed=%d\n",failed);
	return failed ? 1 : 0;
}
