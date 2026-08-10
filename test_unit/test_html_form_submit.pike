#!/usr/bin/env pike
/** HTTP旧页面具名输入框和提交按钮回归测试。 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) results=(["total":0,"passed":0,"failed":0]);

void check(string name,int valid,string detail)
{
	results["total"]++;
	if(valid){
		results["passed"]++;
		werror("[旧HTML表单] ✓ %s\n",name);
	}
	else{
		results["failed"]++;
		werror("[旧HTML表单] ✗ %s: %s\n",name,detail);
	}
}

void test_single_input_purchase()
{
	string response="购买个数(1-20)：\n[int no:...]\n"+
		"[submit 确定购买:yushi_buy_baoshi_confirm binglanyushi 2 3 0 0 ...]";
	string html=HTTP_APID->response_to_html(response,
		"xd01testhtmlform","look","xd01testhtmlform~test-password");
	string hidden_cmd="";
	int token_parsed=sscanf(html,"%*sdata-mud-cmd='%s'%*s",hidden_cmd);
	string resolved=token_parsed==3 ? HTTP_APID->unhide_command(
		"xd01testhtmlform",hidden_cmd+" no=20") : "";
	check("冰蓝玉石数量框会渲染确定购买按钮",
		search(html,"data-mud-name='no'")!=-1 &&
		search(html,"data-mud-submit='mud_form_")!=-1 &&
		search(html,">确定购买</button>")!=-1 &&
		search(html,"submitMudForm(this)")!=-1 &&
		search(html,"[submit 确定购买:")==-1 &&
		resolved=="yushi_buy_baoshi_confirm binglanyushi 2 3 0 0 no=20",
		"购买表单缺少数量字段或提交按钮");
}

void test_multi_input_form()
{
	string response="[int sg:...]金[int ss:...]银\n"+
		"[submit 确定:vendue_confirm fixture ...]";
	string html=HTTP_APID->response_to_html(response,
		"xd01testhtmlform","look","xd01testhtmlform~test-password");
	string form_id="";
	int parsed=sscanf(html,"%*sdata-mud-form='%s'%*s",form_id);
	check("多字段表单共用一个提交分组",
		parsed==3 && form_id!="" &&
		sizeof(html/("data-mud-form='"+form_id+"'"))==3 &&
		search(html,"data-mud-submit='"+form_id+"'")!=-1 &&
		search(html,"data-mud-name='sg'")!=-1 &&
		search(html,"data-mud-name='ss'")!=-1,
		"多字段未绑定到同一表单");
}

void test_multiple_submit_choices()
{
	string response="推荐人账号：[string na:...]\n"+
		"[submit 原二区:present_set 0 xd2 ...]\n"+
		"[submit 原三区:present_set 0 xd3 ...]\n"+
		"[submit 新区:present_set 0 xdX ...]";
	string html=HTTP_APID->response_to_html(response,
		"xd01testhtmlform","look","xd01testhtmlform~test-password");
	string form_id="";
	int parsed=sscanf(html,"%*sdata-mud-form='%s'%*s",form_id);
	check("同一字段支持多个连续提交选项",
		parsed==3 && form_id=="mud_form_1" &&
		sizeof(html/("data-mud-submit='"+form_id+"'"))==4 &&
		search(html,">原二区</button>")!=-1 &&
		search(html,">原三区</button>")!=-1 &&
		search(html,">新区</button>")!=-1,
		"备选提交按钮没有完整复用同一组输入");
}

void test_form_ids_are_unique()
{
	string response="[string first:...]\n[submit 第一组:test_one ...]\n"+
		"[string second:...]\n[submit 第二组:test_two ...]";
	string html=HTTP_APID->response_to_html(response,
		"xd01testhtmlform","look","xd01testhtmlform~test-password");
	check("同一响应中的独立表单使用唯一编号",
		search(html,"data-mud-form='mud_form_1'")!=-1 &&
		search(html,"data-mud-submit='mud_form_1'")!=-1 &&
		search(html,"data-mud-form='mud_form_2'")!=-1 &&
		search(html,"data-mud-submit='mud_form_2'")!=-1,
		"独立表单ID重复或字段被串到上一组");
}

void test_form_attributes_are_escaped_and_posted()
{
	string response="[string note:..*'\"><script>...*20]\n"+
		"[submit 提交:test_form ...]";
	string html=HTTP_APID->response_to_html(response,
		"xd01testhtmlform","look","xd01testhtmlform~pw'\"><script>");
	check("表单属性转义且认证和命令使用POST提交",
		search(html,"form.method='post'")!=-1 &&
		search(html,"form.action='/api/html'")!=-1 &&
		search(html,"data-mud-txd='xd01testhtmlform~pw&#39;&quot;&gt;&lt;script&gt;'")!=-1 &&
		search(html,"value='&#39;&quot;&gt;&lt;script&gt;'")!=-1 &&
		search(html,"value=''><script>")==-1 &&
		search(html,"data-mud-txd='xd01testhtmlform~pw'><script>")==-1,
		"表单值或认证串可能破坏HTML属性边界，或仍通过URL提交");
}

int main()
{
	mixed err=catch{
		test_single_input_purchase();
		test_multi_input_form();
		test_multiple_submit_choices();
		test_form_ids_are_unique();
		test_form_attributes_are_escaped_and_posted();
	};
	if(err)
		check("测试运行时无异常",0,
			describe_error(err)+" "+describe_backtrace(err));
	werror("旧HTML表单测试：总计%d，通过%d，失败%d\n",
		results["total"],results["passed"],results["failed"]);
	return results["failed"]==0 ? 0 : 1;
}
