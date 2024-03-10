#include <globals.h>
#include <mudlib/include/mudlib.h>
inherit LOW_DAEMON;
array(string) appearance_msg_male1 = ({
        "长得伟岸英挺，顾盼之间，神采飞扬。\n",
        "丰姿英伟，气宇轩昂，确实是人中龙凤。\n"
});
array(string) appearance_msg_male2 = ({
        "英俊潇洒，风度翩翩。\n",
        "相貌出众，面目俊朗。\n",
        "面貌清奇，丰姿非俗。\n"
});
array(string) appearance_msg_male3 = ({
        "生得腰圆背厚，面阔口方，骨格不凡。\n",
        "算不上俊朗，但也有几分味道。\n",
        "生得鼻直口方，线条分明，显出刚毅性格。\n"
});
array(string) appearance_msg_male4 = ({
        "长得一副姥姥不疼，舅舅不爱的模样。\n",
        "长得蔫蔫的，一副无精打采的模样。 \n", 
        "五短三粗，肥头大耳，大概是猪八戒的本家。 \n"
});
array(string) appearance_msg_female1 = ({
        "长发如云，肌肤胜雪，不知倾倒了多少英雄豪杰。 \n",
        "俏脸生春，妙目含情，轻轻一笑，不觉让人怦然心动。 \n",
        "风情万种，楚楚动人，当真是我见犹怜。 \n"
});
array(string) appearance_msg_female2 = ({
        "婷婷玉立，容色秀丽，风姿动人。 \n",
        "玉面娇容花含露，纤足细腰柳带烟。 \n",
        "面带晕红，眼含秋波。举手投足之间，确有一番风韵。 \n"
});
array(string) appearance_msg_female3 = ({
        "虽算不上绝世佳人，也颇有几份姿色。 \n",
        "长得还不错，颇有几份姿色。  \n"
});
array(string) appearance_msg_female4 = ({
        "长得比较难看。 \n",
		"长得。。。。。。唉\n"
});
array(string) appearance_msg_kid1 = ({
        "月眉星眼，灵气十足。\n",
        "机灵活泼，神态非凡。\n",
        "面若秋月，色如晓花。\n"
});
array(string) appearance_msg_kid2 = ({
        "隆额大眼，脸色红润。\n",
        "胖胖嘟嘟，逗人喜欢。\n",
        "细皮嫩肉，口齿伶俐。\n"
});
array(string) appearance_msg_kid3 = ({
        "身材矬矮，傻里傻气。\n",
        "肥肥胖胖，小鼻小眼。\n",
        "呆头呆脑，笨手笨脚。\n"
});
array(string) appearance_msg_kid4 = ({
        "蓬头垢脚，脸黄肌瘦。\n",
        "神如木鸡，面有病色。\n",
        "五官不整，四肢不洁。\n"
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
	else return "性别不明，阴阳不详，实在看不出来是个什么模样。\n";
}
