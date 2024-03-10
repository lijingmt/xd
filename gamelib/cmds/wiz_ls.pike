/**
 * wiz_ls.pike
 * author hps
 * Date: 2003/09/13 
 */
#include <command.h>
#include <gamelib/include/gamelib.h>

int main()
{
	string file_name,file_path,result,dir=getcwd();
	array file=get_dir(dir);
	int files,dirs,k,i;
	//if( this_player()->query_name()!="zhubin"||this_player()->query_name()!="wangyan" )	
	//	return 1;
	files=dirs=k=i=0;
	result="";
	if(!sizeof(file)){
		write("%s    没有任何档案。\n\n", dir);
		return 1;
	}
	write("目录: %s\n",dir);
	foreach(file,file_name){
		file_path=dir+"/"+file_name;
		i++;
		result = sprintf("%-20s%s%s",file_name,(Stdio.file_size(file_path)==-2?" <DIR>" : sprintf("%5dk", (Stdio.file_size(file_path)+1023)/1024)),(i%3)?" | ":"\n" )+result;
		k=k+((Stdio.file_size(file_path)+1023)/1024);
	}
	write("%s \n",result);
	//result += sprintf("\n文件有：%d 个，总共：%d K ，目录共有：%d 个。\n",files,k,dirs);
	return 1;		
}
