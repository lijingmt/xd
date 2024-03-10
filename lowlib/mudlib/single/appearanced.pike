#include <globals.h>
#include <mudlib/include/mudlib.h>
inherit LOW_DAEMON;
array(string) appearance_msg_male1 = ({
        "����ΰ��Ӣͦ������֮�䣬��ɷ��\n",
        "����Ӣΰ������������ȷʵ���������\n"
});
array(string) appearance_msg_male2 = ({
        "Ӣ��������������档\n",
        "��ò���ڣ���Ŀ���ʡ�\n",
        "��ò���棬���˷��ס�\n"
});
array(string) appearance_msg_male3 = ({
        "������Բ���������ڷ����Ǹ񲻷���\n",
        "�㲻�Ͽ��ʣ���Ҳ�м���ζ����\n",
        "���ñ�ֱ�ڷ��������������Գ������Ը�\n"
});
array(string) appearance_msg_male4 = ({
        "����һ�����Ѳ��ۣ��˾˲�����ģ����\n",
        "��������ģ�һ���޾���ɵ�ģ���� \n", 
        "������֣���ͷ������������˽�ı��ҡ� \n"
});
array(string) appearance_msg_female1 = ({
        "�������ƣ�����ʤѩ����֪�㵹�˶���Ӣ�ۺ��ܡ� \n",
        "������������Ŀ���飬����һЦ������������Ȼ�Ķ��� \n",
        "�������֣��������ˣ��������Ҽ������� \n"
});
array(string) appearance_msg_female2 = ({
        "������������ɫ���������˶��ˡ� \n",
        "���潿�ݻ���¶������ϸ�������̡� \n",
        "����κ죬�ۺ��ﲨ������Ͷ��֮�䣬ȷ��һ�����ϡ� \n"
});
array(string) appearance_msg_female3 = ({
        "���㲻�Ͼ������ˣ�Ҳ���м�����ɫ�� \n",
        "���û��������м�����ɫ��  \n"
});
array(string) appearance_msg_female4 = ({
        "���ñȽ��ѿ��� \n",
		"���á�������������\n"
});
array(string) appearance_msg_kid1 = ({
        "��ü���ۣ�����ʮ�㡣\n",
        "������ã���̬�Ƿ���\n",
        "�������£�ɫ��������\n"
});
array(string) appearance_msg_kid2 = ({
        "¡����ۣ���ɫ����\n",
        "�����ལ�����ϲ����\n",
        "ϸƤ���⣬�ڳ�������\n"
});
array(string) appearance_msg_kid3 = ({
        "����󰫣�ɵ��ɵ����\n",
        "�ʷ����֣�С��С�ۡ�\n",
        "��ͷ���ԣ����ֱ��š�\n"
});
array(string) appearance_msg_kid4 = ({
        "��ͷ���ţ����Ƽ��ݡ�\n",
        "����ľ�������в�ɫ��\n",
        "��ٲ�������֫���ࡣ\n"
});
string `()(string gender,int appearance){
	if ( gender == "male" ) {
		if ( appearance>=25 )
			return ( appearance_msg_male1[random(sizeof(appearance_msg_male1))]);
		else if ( appearance>=20 )
			return ( appearance_msg_male2[random(sizeof(appearance_msg_male2))]);
		else if ( appearance>=15 )
			return ( appearance_msg_male3[random(sizeof(appearance_msg_male3))]);
		else    return ( appearance_msg_male4[random(sizeof(appearance_msg_male4))]);
	}

	if ( gender == "female" ) {
		if ( appearance>=25 )
			return ( appearance_msg_female1[random(sizeof(appearance_msg_female1))]);
		else if ( appearance>=20 )
			return ( appearance_msg_female2[random(sizeof(appearance_msg_female2))]);
		else if ( appearance>=15 )
			return ( appearance_msg_female3[random(sizeof(appearance_msg_female3))]);
		else   return ( appearance_msg_female4[random(sizeof(appearance_msg_female4))]);
	}
	else return "�Ա������������꣬ʵ�ڿ��������Ǹ�ʲôģ����\n";
}
