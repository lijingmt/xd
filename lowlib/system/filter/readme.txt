[name:cmd]
[name{num}:cmd]
	�������ӣ�������Ϊname�����֧�ֿ�ݼ�����num�����ݼ��������������cmd��ϵͳ��

[wml wml_output]
	�����ǰfilterΪwml��ֱ�����wml_output��
[xhtml xhtml_output]
	�����ǰfilterΪxhtml��ֱ�����xhtml_output��

[<some tag>]
	ֱ�����<some tag>���ѹ�ʱ��
	
[ol]
[/ol]
	��wap2.0���<ol></ol>���ѹ�ʱ��

[prev name:cmd]
	����һ�����ӣ����ӵ�����Ϊname�����û�������Ӻ󣬽�����cmd�ͻ�ϵͳ�����ӹܡ����ء�����ֻҪ���ܣ���ÿҳֻӦ��ʹ��һ�Ρ�

[submit name:cmd...]
	����һ��submit���ӣ����ӵ�����Ϊname�����û�������Ӻ󣬽�����cmd�ͻ�ϵͳ���������в����������
	���磺"�ż����⣺[string subject:...]\n �ż����ݣ�[string body:...]\n [submit ȷ��:mailbox_mail to=peterpan ...]"�ύ"mailbox_mail to=peterpan subject=some_subject body=some_body"
	"�ż����⣺[string subject:...]\n �ż����ݣ�[string body:...]\n [submit ȷ��:mailbox_mail to=peterpan...]"�ύ"mailbox_mail to=peterpansubject=some_subject body=some_body"
	
[select arg data:cmd...]
[select arg{name} data:cmd...]
	����һ�鵥ѡ�����ӵ�����Ϊname��nameȷʡʱΪ��ȷ�ϡ����û����ѡ���Ժ���"cmd+arg=ѡ����"��ϵͳ��
	data�ĸ�ʽΪ��ѡ������1{ѡ����1} ѡ������2{ѡ����2} ѡ������3{ѡ����3} ����
	���磺"[select color ��ɫ{red} ��ɫ{white}:set ...]"�ύ"set color=red"

[passwd arg:...]
[int arg:...]
[string arg:...]
[arg:...]
	����һ��input���������ݷ��ڲ���arg�С�

[passwd arg:cmd...]
[int arg:cmd...]
[string arg:cmd...]
[arg:cmd...]
	����һ��input��͡�ȷ�������ӣ��û���ȷ�������Ժ�"cmd+��������"�ͻ�ϵͳ��

[url name:href]
	����һ������url href�����ӣ�������Ϊname��

[imgurl alt:href]
	����һ��ͼƬ������������Ϊalt��ͼƬurlΪhref��

[aimg alt:acmd;cmd]
	����һ��ͼƬ���ӣ�����������Ϊalt��ͼƬ������acmd��ã��û����������cmd����ϵͳ��

[aimgurl alt:ahref;cmd]
	����һ��ͼƬ���ӣ�����������Ϊalt��ͼƬurl��Ϊahref���û����������cmd����ϵͳ��

[option name:cmd]
	����һ��option���ʾname��һ����ѡ�з�������cmd��ϵͳ
