#!/usr/bin/env pike
/**
 * Vue 镜像构建链静态契约测试。
 *
 * 覆盖：
 * - rebuild-image.sh 在 Docker 前调用统一前端构建脚本
 * - BUILD_FRONTEND_ONLY 验证入口
 * - app/realm CSS、JS、manifest 与历史 dist 同步
 * - Dockerfile 将 web 产物复制到 Tomcat ROOT
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

mapping(string:int) test_results = ([
	"total":0,
	"passed":0,
	"failed":0,
]);

void test_start(string name)
{
	test_results["total"]++;
	werror("\n[Vue构建链 %d] %s\n",test_results["total"],name);
}

void test_pass()
{
	test_results["passed"]++;
	werror("  ✓ 通过\n");
}

void test_fail(string reason)
{
	test_results["failed"]++;
	werror("  ✗ 失败: %s\n",reason);
}

void test_rebuild_entry_contract()
{
	test_start("镜像构建前强制执行统一前端构建");
	string source = Stdio.read_file(ROOT+"/rebuild-image.sh");
	int frontend_call = -1;
	int image_call = -1;

	if(source){
		frontend_call = search(source,
			"    build_vue_frontend\n");
		image_call = search(source,"    build_image\n");
	}
	if(source &&
	   search(source,
		"scripts/build/build_vue_frontend.sh")!=-1 &&
	   search(source,"BUILD_FRONTEND_ONLY")!=-1 &&
	   frontend_call!=-1 && image_call!=-1 &&
	   frontend_call<image_call)
		test_pass();
	else
		test_fail("前端构建入口、仅前端模式或调用顺序错误");
}

void test_shared_build_script_contract()
{
	test_start("统一脚本执行测试、构建和产物一致性校验");
	string source = Stdio.read_file(
		ROOT+"/scripts/build/build_vue_frontend.sh");

	if(source &&
	   search(source,"npm test")!=-1 &&
	   search(source,"npm run build")!=-1 &&
	   search(source,"STORY_SOURCE_DIR")!=-1 &&
	   search(source,"STORY_OUTPUT_DIR")!=-1 &&
	   search(source,"css/realm.css")!=-1 &&
	   search(source,"vendor/vue.global.prod.js")!=-1 &&
	   search(source,"cmp -s")!=-1 &&
	   search(source,"Dockerfile.all")!=-1)
		test_pass();
	else
		test_fail("统一前端构建脚本缺少测试、构建或校验步骤");
}

void test_vue_source_contract()
{
	test_start("Vue源码完整进入正式和历史产物目录");
	string build_source =
		Stdio.read_file(ROOT+"/vue_source/build.js");
	string index_source =
		Stdio.read_file(ROOT+"/vue_source/index.html");

	if(build_source && index_source &&
	   search(build_source,"css', 'app.css")!=-1 &&
	   search(build_source,"css', 'realm.css")!=-1 &&
	   search(build_source,"js', 'app.js")!=-1 &&
	   search(build_source,"'vue.global.prod.js'")!=-1 &&
	   search(build_source,"'VUE_LICENSE.txt'")!=-1 &&
	   search(build_source,"legacyDistDir")!=-1 &&
	   search(index_source,"manifest.json")!=-1 &&
	   search(index_source,"css/realm.css?v=BUILD_VERSION")!=-1 &&
	   search(index_source,
		"vendor/vue.global.prod.js?v=BUILD_VERSION")!=-1 &&
	   search(index_source,"unpkg.com/vue")==-1)
		test_pass();
	else
		test_fail("Vue源码复制或入口引用契约不完整");
}

void test_manifest_contract()
{
	test_start("PWA路径保持相对且引用实际favicon");
	string source =
		Stdio.read_file(ROOT+"/vue_source/manifest.js");

	if(source &&
	   search(source,"id: './'")!=-1 &&
	   search(source,"start_url: './'")!=-1 &&
	   search(source,"scope: './'")!=-1 &&
	   search(source,"src: 'favicon.ico'")!=-1)
		test_pass();
	else
		test_fail("manifest相对路径或favicon配置错误");
}

void test_auto_browser_login_contract()
{
	test_start("自动浏览器登录与HTML直达链接保持兼容");
	string index_source =
		Stdio.read_file(ROOT+"/vue_source/index.html");
	string app_source =
		Stdio.read_file(ROOT+"/vue_source/js/app.js");

	if(index_source && app_source &&
	   search(index_source,"<div class=\"auth-form\">")!=-1 &&
	   search(index_source,"@click=\"doLogin\"")!=-1 &&
	   search(index_source,"@keyup.enter=\"doLogin\"")!=-1 &&
	   search(index_source,"type=\"button\"")!=-1 &&
	   search(index_source,"name=\"username\"")==-1 &&
	   search(index_source,"name=\"password\"")==-1 &&
	   search(index_source,"<form class=\"auth-form\"")==-1 &&
	   search(index_source,
		"@click=\"handleMudButtonClick($event, segment.cmd)\"")!=-1 &&
	   search(index_source,
		"@click.prevent=\"!htmlMode")==-1 &&
	   search(app_source,
		"handleMudButtonClick(event, cmd)")!=-1 &&
	   search(app_source,"if (this.htmlMode)")!=-1 &&
	   search(app_source,"event.preventDefault();")!=-1)
		test_pass();
	else
		test_fail("登录按钮或HTML模式链接会阻止自动浏览器操作");
}

void test_docker_copy_contract()
{
	test_start("Docker镜像复制web产物到Tomcat ROOT");
	string source =
		Stdio.read_file(ROOT+"/docker/Dockerfile.all");

	if(source &&
	   search(source,
		"COPY web /usr/local/tomcat/webapps/ROOT")!=-1)
		test_pass();
	else
		test_fail("Dockerfile未复制正式前端目录");
}

void test_game_number_format_contract()
{
	test_start("新旧网页统一使用中文数值格式器");
	string formatter = Stdio.read_file(
		ROOT+"/web/includes/game-number-format.js");
	string index_source = Stdio.read_file(
		ROOT+"/vue_source/index.html");
	string app_source = Stdio.read_file(
		ROOT+"/vue_source/js/app.js");
	string html5_source = Stdio.read_file(
		ROOT+"/lowlib/system/filter/html5.pike");
	string html6_source = Stdio.read_file(
		ROOT+"/lowlib/system/filter/html6.pike");
	string html6_dark_source = Stdio.read_file(
		ROOT+"/lowlib/system/filter/html6_dark.pike");
	string html6_copy_source = Stdio.read_file(
		ROOT+"/lowlib/system/filter/html6 copy.pike");

	if(formatter && index_source && app_source &&
	   html5_source && html6_source &&
	   html6_dark_source && html6_copy_source &&
	   search(formatter,"compact_game_numbers")!=-1 &&
	   search(formatter,"formatExactNumber")!=-1 &&
	   search(formatter,"data-number-format")!=-1 &&
	   search(formatter,"万亿")!=-1 &&
	   search(formatter,"穰")!=-1 &&
	   search(index_source,
		"data-auto-format=\"false\"")!=-1 &&
	   search(index_source,
		"renderGameText(segment.label, true)")!=-1 &&
	   search(app_source,
		"formatGameNumber(value, options = {})")!=-1 &&
	   search(html5_source,
		"includes/game-number-format.js")!=-1 &&
	   search(html6_source,
		"includes/game-number-format.js")!=-1 &&
	   search(html6_dark_source,
		"includes/game-number-format.js")!=-1 &&
	   search(html6_copy_source,
		"includes/game-number-format.js")!=-1)
		test_pass();
	else
		test_fail("格式器、Vue出口或旧HTML过滤器接入不完整");
}

void test_frontend_playability_gate()
{
	test_start("真实Vue首屏渲染门禁已接入测试链");
	string package_source = Stdio.read_file(
		ROOT+"/vue_source/package.json");
	string test_source = Stdio.read_file(
		ROOT+"/vue_source/tests/frontend-playability.test.js");
	string index_source = Stdio.read_file(
		ROOT+"/vue_source/index.html");

	if(package_source && test_source && index_source &&
	   search(package_source,
		"tests/frontend-playability.test.js")!=-1 &&
	   search(test_source,"createSSRApp")!=-1 &&
	   search(test_source,"renderToString")!=-1 &&
	   search(test_source,"componentOptions.computed")!=-1 &&
	   search(index_source,"playerLevelAuraClass()") == -1)
		test_pass();
	else
		test_fail("真实渲染、computed误调用扫描或白屏回归断言缺失");
}

void test_high_realm_contrast_contract()
{
	test_start("离三界高阶装备在新旧界面均使用高对比颜色");
	string realm_source = Stdio.read_file(
		ROOT+"/vue_source/css/realm.css");
	string renderer_source = Stdio.read_file(
		ROOT+"/gamelib/single/daemons/_http_api_mod/html_renderer.pike");

	if(realm_source && renderer_source &&
	   search(realm_source,
		"--realm-lisan3-ink: #9A3412;")!=-1 &&
	   search(realm_source,
		"--realm-lisan3-ink: #FFD08A;")!=-1 &&
	   search(realm_source,
		"color: var(--realm-lisan3-ink) !important;")!=-1 &&
	   search(realm_source,
		"text-shadow: none !important;")!=-1 &&
	   search(renderer_source,
		"color:#9A3412!important;border-color:#C2410C!important;"
		"background:#FFF7ED!important;text-shadow:none!important")!=-1 &&
	   search(renderer_source,
		"color:#FFD08A!important;border-color:#F59E0B!important;"
		"background:#2C1B0F!important;text-shadow:none!important")!=-1)
		test_pass();
	else
		test_fail("境界装备高对比样式未同步到新旧界面");
}

void test_deployed_frontend_artifacts()
{
	test_start("正式与历史Vue产物可加载且和源码同步");
	string source_js = Stdio.read_file(
		ROOT+"/vue_source/js/app.js");
	string web_js = Stdio.read_file(
		ROOT+"/web/web_vue/js/app.js");
	string dist_js = Stdio.read_file(
		ROOT+"/vue_source/dist/js/app.js");
	string web_index = Stdio.read_file(
		ROOT+"/web/web_vue/index.html");
	string dist_index = Stdio.read_file(
		ROOT+"/vue_source/dist/index.html");
	string web_vue = Stdio.read_file(
		ROOT+"/web/web_vue/vendor/vue.global.prod.js");
	string dist_vue = Stdio.read_file(
		ROOT+"/vue_source/dist/vendor/vue.global.prod.js");
	int story_atlases_valid = 1;
	for(int volume=1;volume<=9;volume++){
		string filename = sprintf("volume_%02d.png",volume);
		string source_path = ROOT+"/images/illusion_s1/story/"+filename;
		string deployed_path = ROOT+"/web/images/illusion_s1/story/"+filename;
		if(Stdio.file_size(source_path)<1024*1024 ||
		   Stdio.read_file(source_path)!=Stdio.read_file(deployed_path))
			story_atlases_valid = 0;
	}

	if(source_js && web_js && dist_js &&
	   web_index && dist_index && web_vue && dist_vue &&
	   sizeof(source_js)>1000 && source_js==web_js && source_js==dist_js &&
	   sizeof(web_index)>1000 && sizeof(dist_index)>1000 &&
	   sizeof(web_vue)>100000 && web_vue==dist_vue &&
	   search(web_index,"BUILD_VERSION")==-1 &&
	   search(dist_index,"BUILD_VERSION")==-1 &&
	   search(web_index,"playerLevelAuraClass()")==-1 &&
	   search(dist_index,"playerLevelAuraClass()")==-1 &&
	   search(web_index,"vendor/vue.global.prod.js?v=v")!=-1 &&
	   search(web_index,"js/app.js?v=v")!=-1 && story_atlases_valid)
		test_pass();
	else
		test_fail("Vue正式/历史产物缺失、过期或仍含白屏回归代码");
}

void print_summary()
{
	werror("\n========================================\n");
	werror("Vue构建链测试完成！总计: %d, 通过: %d, 失败: %d\n",
		test_results["total"],
		test_results["passed"],
		test_results["failed"]);
	werror("========================================\n");
}

int main()
{
	test_rebuild_entry_contract();
	test_shared_build_script_contract();
	test_vue_source_contract();
	test_manifest_contract();
	test_auto_browser_login_contract();
	test_docker_copy_contract();
	test_game_number_format_contract();
	test_frontend_playability_gate();
	test_high_realm_contrast_contract();
	test_deployed_frontend_artifacts();
	print_summary();
	if(test_results["failed"]==0)
		return 0;
	return 1;
}
