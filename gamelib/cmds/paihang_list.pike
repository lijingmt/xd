#include <command.h>
#include <gamelib/include/gamelib.h>  
//��ָ����ʾ����������
int main(string arg)
{
	string type = "";
	int pageNum = 0;
	sscanf(arg,"%s %d",type,pageNum);
	//werror("========== arg = "+  arg  +"==========\n");
	//werror("========== type = "+  type  +"==========\n");
	//werror("========== pageNum = "+  pageNum  +"==========\n");
	mapping(string:string) titles_with_link = ([
			"all_fee":"[����:paihang_list all_fee 1]",
			"account":"[�Ƹ�:paihang_list account 1]",
			"mark":"[�ۺ�ʵ��:paihang_list mark 1]",
			"lunhuipt":"[�ֻ�ֵ:paihang_list lunhuipt 1]",
			"honerpt":"[����/ħ��:paihang_list honerpt 1]",
			]);
	mapping(string:string) titles_without_link = ([
			"all_fee":"����",
			"account":"�Ƹ�",
			"mark":"�ۺ�ʵ��",
			"lunhuipt":"�ֻ�ֵ",
			"honerpt":"����/ħ��",
			]);
	string s = "====== �ɵ����а� ======\n\n";

	foreach(sort(indices(titles_with_link)),string single){
		if(single == type)
			s += (titles_without_link[single] +"|");
		else
			s += (titles_with_link[single] +"|");
	}
	s += "\n";

//��ʼ��ȡ������Ϣ
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
				s += (i+1)+"��"+name_cn;
				if(type == "mark")
					s +="("+tmp["mark"]+")";
				else if(type == "lunhuipt")
					s +="("+(int)tmp["lunhuipt"]+")";
				s +="\n";
			}
		}
		s += "------------\n";
		if(pageNum>1)
			s += "[��һҳ:paihang_list "+ type +" "+ (pageNum-1) +"] ";
		if(endNum < listSize-1)
			s += "[��һҳ:paihang_list "+ type +" "+ (pageNum+1) +"]\n";
	}
	else
		s += "��δ����\n";
	s += "\n[������Ϸ:look]\n";
	write(s);
	return 1;
}
