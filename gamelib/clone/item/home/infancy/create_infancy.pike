#define ROOTDIR "./"
int main(int argc, array(string) argv){
	//判断输入参数合法性///////////////////////////////////////
	if(argc==2){
		if(search(argv[argc-1],".csv")!=-1)
			write("需要处理的文档名称为："+argv[argc-1]+"\n");	
		else{
			write("需要处理的文档名称为："+argv[argc-1]+"\n");	
			write("但是该文件并非一个合法的csv处理文档，请返回检查!\n");
			return 0;
		}
	}
	else{
		write("参数错误，请返回检查！\n");	
		return 0;
	}
	//判断输入参数合法性///////////////////////////////////////
	array(string) all_lines;
	array(string) line_values;
	mapping (int:string) item_level_index=([]);
	string all_data=Stdio.read_file(ROOTDIR+argv[1]);
	all_lines=all_data/"\r\n";
	
	string tempString;
	array tempArray;
	int tempInt = 0;
	for(int i=1;i<sizeof(all_lines)-1;i++){
		string writeFile="";
		tempArray = all_lines[i]/",";
		
		writeFile += "#include <globals.h>\n#include <gamelib/include/gamelib.h>\ninherit WAP_INFANCY;\n";//头文件信息
		writeFile += "void create(){\n\tname=object_name(this_object());\n";//物品create()方法头部
		//物品中文名称/////////////////////////
		writeFile += "\tname_cn=" + "\"" +tempArray[1]+"\";\n";
		writeFile += "\tunit=" + "\""+tempArray[2]+"\";\n";
		writeFile += "\tpicture=name;\n";
		writeFile += "\tdesc=" + "\""+tempArray[3]+"\";\n";
		writeFile += "\tamount=1;\n"; 
		writeFile += "\tset_item_canDrop(1);\n\tset_item_canGet(1);\n\tset_item_canTrade(1);\n\tset_item_canSend(1);\n\tset_item_canStorage(1);\n\tvalue=100;\n";
		writeFile += "\tset_item_type(" + "\"" + tempArray[4]+"\");\n";
		writeFile += "\tset_grownItem_path(" + "\"" +tempArray[5]+"\");\n";
		writeFile += "\tset_harvest_desc(" +"\"" + tempArray[6]+"\");\n";
		writeFile += "\thomeLevel_limit = "+tempArray[7]+ ";\n";
		writeFile += "}";
		
		array dir = tempArray[0]/"/";
		if(!Stdio.exist(dir[0])) mkdir(ROOTDIR+dir[0]);
		Stdio.write_file(ROOTDIR+tempArray[0],writeFile);
	}
	return 1;
}
