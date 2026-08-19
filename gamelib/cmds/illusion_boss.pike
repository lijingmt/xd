#include <command.h>
#include <gamelib/include/gamelib.h>

/** S1首领预警应对；实际对象、房间、目标、时限和nonce全部由服务端复核。 */
int main(string|zero arg)
{
	object me=this_player();
	array(string) parts=arg ? String.trim_all_whites(arg)/" " : ({});
	mapping result=([]);
	mixed answer_err;
	if(!me)
		return 0;
	if(sizeof(parts)!=4 || parts[0]!="answer"){
		write("首领应对入口无效；请只点击本场战斗刚刚出现的预警按钮。\n"+
			"[返回游戏:look]\n");
		return 1;
	}
	// 首领机制是附加玩法。即使守护进程在NPC析构/切换Worker边界
	// 抛异常，也要给玩家一个可返回的确定页面，不能把异常穿透HTTP。
	answer_err=catch{
		result=ILLUSION_BOSSD->answer(me,parts[1],parts[2],parts[3]);
	};
	if(answer_err || !mappingp(result))
		result=(["ok":0,
			"message":"首领应对状态正在切换，本次未产生效果，请返回战斗等待下一次预警。"]) ;
	write((string)result["message"]+"\n[返回战斗:look]\n");
	return 1;
}
