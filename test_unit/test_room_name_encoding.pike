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
]);

int main()
{
	int failed = 0;

	werror("\n========================================\n");
	werror("历史地图房间名编码回归测试\n");
	werror("========================================\n");

	foreach(expected_room_names;string room_path;string expected_name){
		string source = Stdio.read_file(ROOT+"/"+room_path);
		if(source && search(source,"name_cn")!=-1 &&
		   search(source,"\""+expected_name+"\"")!=-1){
			werror("  ✓ %s：%s\n",room_path,expected_name);
		}
		else{
			failed++;
			werror("  ✗ %s：应为%s\n",room_path,expected_name);
		}
	}

	werror("[房间名编码] complete failed=%d\n",failed);
	return failed ? 1 : 0;
}
