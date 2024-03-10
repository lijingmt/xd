#!/usr/local/bin/pike

string  log_pre = "project";
int maxSize = 50*1024*1024;

/*int main(int argv,array(string) args)
{
	for(int i = 0 ; i < 100; i++)
	{
		append_time(i + ":time");
		append_size(i + ":size");
	}
	return 1;
}*/
void create(string|void logNamePre)
{	
	if(logNamePre)
	{
		logNamePre = String.trim_all_whites(logNamePre);
		if(sizeof(logNamePre) != 0)
			log_pre = logNamePre;
	}
}

void append_time(string content)
{
	string log_file = log_pre + "-" + getTimeShortDesc() + ".log";
	if(content)
		Stdio.append_file(log_file,getTimeLongDesc() + " -- " + content + "\n");
}

void debug_time(string content)
{
	string log_file = log_pre + "-" + getTimeShortDesc() + ".log";
	if(content)
		Stdio.append_file(log_file,"DEBUG "+getTimeLongDesc() + " -- " + content + "\n");
}

void error_time(string content)
{
	string log_file = log_pre + "-" + getTimeShortDesc() + ".log";
	if(content)
		Stdio.append_file(log_file,"ERROR "+getTimeLongDesc() + " -- " + content + "\n");
}

void info_time(string content)
{
	string log_file = log_pre + "-" + getTimeShortDesc() + ".log";
	if(content)
		Stdio.append_file(log_file,"INFO "+getTimeLongDesc() + " -- " + content + "\n");
}

void stat_time(string content)
{
	string log_file = log_pre + "-" + getTimeShortDesc() + ".log";
	if(content)
		Stdio.append_file(log_file,"STAT "+getTimeLongDesc() + " -- " + content + "\n");
}

void append_size(string content)
{
	string log_file = log_pre + ".log";
	Stdio.Stat stat = file_stat(log_file);
	int fileSize = 0;
	if(stat)
		fileSize = stat->size;
	if(fileSize >= maxSize)
	{
		int i = 1;
		for(int i = 1; i < 50; i++)
		{
			string ext_log_file = log_file  + "." + i;
			if(!Stdio.exist(ext_log_file))
			{
				mv(log_file,ext_log_file);
				break;
			}
		}
	}

	if(content)
		Stdio.append_file(log_file,getTimeLongDesc() + " -- " + content + "\n");
}

void setFileSize(string|int size)
{
	if(intp(size))	
	{
		if(size > 0)
			maxSize = size;
	}
	else
	{
		if(size)
		{
			size = String.trim_all_whites(size);
			if(sizeof(size) != 0)
			{
				size = upper_case(size);

				mixed err=catch
				{
					int num = (int)size[..(sizeof(size)-2)];
					string unit = (string)size[(sizeof(size)-1)..];
					if("G" == unit)
						maxSize = num*1024*1024*1024;
					else if("M" == unit)
						maxSize = num*1024*1024;
					else if("K" == unit)
						maxSize = num*1024;
					else if("B" == unit)
						maxSize = num;
				};
				if(err)
				{
					string log_file = log_pre + ".log";
					Stdio.append_file(log_file,getTimeLongDesc() + " -- [setFileSize("+ size + ")] [error]\n");
				}
			}
		}
	}
}

string getFileSize()
{
	return maxSize+"b";
}

void setFilePre(string filename)
{
	if(filename)
	{
		filename = String.trim_all_whites(filename);
		if(sizeof(filename) != 0)
			log_pre = filename;
	}
}

string getFilePre()
{
	return log_pre;
}

string getTimeShortDesc()
{
	mapping now_time = localtime(time());                                                                     
	int year = now_time["year"] + 1900;
	int mon = now_time["mon"]+1;                                               
	int day = now_time["mday"];                                                                                 
	return year + "-" + mon + "-" + day;
}

string getTimeLongDesc()
{
	mapping now_time = localtime(time());                                                                     
	int year = now_time["year"] + 1900;
	int mon = now_time["mon"]+1;                                               
	int day = now_time["mday"];                                                                                 
	int hour = now_time["hour"];
	int min = now_time["min"];
	int sec = now_time["sec"];

	return year + "-" + mon + "-" + day  + " " + hour + ":" + min + ":" +sec;
}
