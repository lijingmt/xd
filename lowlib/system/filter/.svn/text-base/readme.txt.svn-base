[name:cmd]
[name{num}:cmd]
	生成连接，连接名为name，如果支持快捷键，用num做其快捷键，点击后发送命令cmd回系统。

[wml wml_output]
	如果当前filter为wml，直接输出wml_output。
[xhtml xhtml_output]
	如果当前filter为xhtml，直接输出xhtml_output。

[<some tag>]
	直接输出<some tag>（已过时）
	
[ol]
[/ol]
	在wap2.0输出<ol></ol>（已过时）

[prev name:cmd]
	生成一个连接，连接的文字为name，当用户点此连接后，将命令cmd送回系统。并接管“返回”键（只要可能）。每页只应该使用一次。

[submit name:cmd...]
	生成一个submit连接，连接的文字为name，当用户点此连接后，将命令cmd送回系统。并将所有参数附于其后。
	例如："信件标题：[string subject:...]\n 信件内容：[string body:...]\n [submit 确定:mailbox_mail to=peterpan ...]"提交"mailbox_mail to=peterpan subject=some_subject body=some_body"
	"信件标题：[string subject:...]\n 信件内容：[string body:...]\n [submit 确定:mailbox_mail to=peterpan...]"提交"mailbox_mail to=peterpansubject=some_subject body=some_body"
	
[select arg data:cmd...]
[select arg{name} data:cmd...]
	生成一组单选框，连接的文字为name，name确省时为“确认”，用户完成选择以后发送"cmd+arg=选项名"回系统。
	data的格式为：选项文字1{选项名1} 选项文字2{选项名2} 选项文字3{选项名3} ……
	例如："[select color 红色{red} 白色{white}:set ...]"提交"set color=red"

[passwd arg:...]
[int arg:...]
[string arg:...]
[arg:...]
	生成一个input框，输入内容放于参数arg中。

[passwd arg:cmd...]
[int arg:cmd...]
[string arg:cmd...]
[arg:cmd...]
	生成一个input框和“确定”连接，用户点确定连接以后将"cmd+输入内容"送回系统。

[url name:href]
	生成一个连向url href的连接，连接名为name。

[imgurl alt:href]
	生成一个图片，下载中文字为alt，图片url为href。

[aimg alt:acmd;cmd]
	生成一个图片连接，下载中文字为alt，图片由命令acmd获得，用户点击后将命令cmd发回系统。

[aimgurl alt:ahref;cmd]
	生成一个图片连接，下载中文字为alt，图片url由为ahref，用户点击后将命令cmd发回系统。

[option name:cmd]
	生成一个option项，显示name，一旦被选中发送命令cmd回系统
