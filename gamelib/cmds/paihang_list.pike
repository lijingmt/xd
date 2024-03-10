#include <command.h>
#include <gamelib/include/gamelib.h>  
//此指令显示捐赠的排行
int main(string arg)
{
	string type = "";
	int pageNum = 0;
	sscanf(arg,"%s %d",type,pageNum);
	//werror("========== arg = "+  arg  +"==========\n");
	//werror("========== type = "+  type  +"==========\n");
	//werror("========== pageNum = "+  pageNum  +"==========\n");
	mapping(string:string) titles_with_link = ([
			"all_fee":"[捐赠:paihang_list all_fee 1]",
			"account":"[财富:paihang_list account 1]",
			"mark":"[综合实力:paihang_list mark 1]",
			"lunhuipt":"[轮回值:paihang_list lunhuipt 1]",
			"honerpt":"[仙气/魔气:paihang_list honerpt 1]",
			]);
	mapping(string:string) titles_without_link = ([
			"all_fee":"捐赠",
			"account":"财富",
			"mark":"综合实力",
			"lunhuipt":"轮回值",
			"honerpt":"仙气/魔气",
			]);
	string s = "====== 仙道排行榜 ======\n\n";

	foreach(sort(indices(titles_with_link)),string single){
		if(single == type)
			s += (titles_without_link[single] +"|");
		else
			s += (titles_with_link[single] +"|");
	}
	s += "\n";

//开始获取排行信息
	//werror("======== hahahah ==========\n");
	array(mapping(string:mixed)) top_list = PAIHANGD->query_toplist(type);
	if(top_list && sizeof(top_list)){
		//werror("===== sizeof(top_list) = "+sizeof(top_list)+"========\n");
		int listSize = sizeof(top_list);
		int startNum = (pageNum-1)*10;
		int endNum = pageNum*10-1;
		if(startNum<0)startNum=0;
		if(endNum<0)endNum=startNum;
		//werror("==== startNum = "+ startNum +"========\n");
		//werror("==== endNum = "+ endNum +"========\n");
		if(endNum>listSize)
			endNum = listSize-1;
		int j = 0;
		for(int i=startNum;i<=endNum;i++){
			mapping tmp = top_list[i];
			string name_cn = tmp["name_cn"];
			if(name_cn && sizeof(name_cn)){
				s += (i+1)+"．"+name_cn;
				if(type == "mark")
					s +="("+tmp["mark"]+")";
				else if(type == "lunhuipt")
					s +="("+(int)tmp["lunhuipt"]+")";
				s +="\n";
			}
		}
		s += "------------\n";
		if(pageNum>1)
			s += "[上一页:paihang_list "+ type +" "+ (pageNum-1) +"] ";
		if(endNum < listSize-1)
			s += "[下一页:paihang_list "+ type +" "+ (pageNum+1) +"]\n";
	}
	else
		s += "暂未发榜\n";
	s += "\n[返回游戏:look]\n";
	write(s);
	return 1;
}
