/**
 * Terms of Service Screen
 * 用户服务协议 - 仙道
 * 与网站版本保持一致: https://www.wapmud.com/gamehome/
 */

import React from 'react';
import {
  View,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  SafeAreaView,
} from 'react-native';


export default function TermsOfServiceScreen({ onClose }) {
  return (
    
    <View style={styles.container}>
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.header}>
          <Text style={styles.headerTitle}>📜 用户服务条款</Text>
          <TouchableOpacity onPress={onClose}>
            <Text style={styles.closeButton}>✕</Text>
          </TouchableOpacity>
        </View>

        <ScrollView style={styles.content} contentContainerStyle={styles.contentContainer}>
          <Text style={styles.updateDate}>最后更新：2026年9月12日</Text>

          {/* 重要提示 */}
          <View style={[styles.section, styles.warningSection]}>
            <Text style={styles.warningTitle}>⚠️ 重要提示</Text>
            <Text style={styles.text}>
              使用仙道游戏服务前，请仔细阅读本条款。使用本游戏即表示您同意遵守本服务条款的所有内容。
            </Text>
          </View>

          {/* 1. 服务说明 */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>1. 服务说明</Text>
            <Text style={styles.text}>
              仙道（以下简称"本游戏"）是由 WAPMUD 开发运营的免费文字游戏。本服务条款适用于所有使用本游戏的用户。
            </Text>
            <Text style={styles.text}>
              我们保留随时修改、暂停或终止全部或部分服务的权利，恕不另行通知。
            </Text>
          </View>

          {/* 2. 虚拟物品性质声明 - 最重要 */}
          <View style={[styles.section, styles.importantSection]}>
            <Text style={styles.sectionTitle}>2. 虚拟物品性质声明 ⚠️</Text>

            <Text style={styles.subTitle}>2.1 虚拟物品的定义</Text>
            <Text style={styles.text}>本游戏内的所有"虚拟物品"包括但不限于：</Text>
            <Text style={styles.bullet}>• 游戏角色（账号）</Text>
            <Text style={styles.bullet}>• 虚拟货币（游戏币、元宝等）</Text>
            <Text style={styles.bullet}>• 虚拟装备、道具、材料</Text>
            <Text style={styles.bullet}>• 虚拟宠物、坐骑</Text>
            <Text style={styles.bullet}>• 游戏内技能、等级、经验值</Text>
            <Text style={styles.bullet}>• 任何其他游戏内获取的虚拟内容</Text>

            <Text style={styles.subTitle}>2.2 虚拟物品的法律性质</Text>
            <View style={styles.alertBox}>
              <Text style={styles.alertTitle}>📌 请用户务必仔细阅读并充分理解以下条款：</Text>
              <Text style={styles.alertItem}>
                <Text style={styles.highlight}>虚拟物品 = 使用许可（License）</Text>
                {"\n"}游戏内的所有虚拟物品均代表用户在游戏服务有效期内{" "}
                <Text style={styles.highlight}>使用</Text>该物品的许可，而非对该物品的{" "}
                <Text style={styles.highlight}>所有权</Text>。
              </Text>
              <Text style={styles.alertItem}>
                <Text style={styles.highlight}>不属于用户财产</Text>
                {"\n"}所有虚拟物品的法律所有权归游戏运营商所有，用户仅享有在游戏服务期间内按照游戏规则使用该物品的权利。
              </Text>
              <Text style={styles.alertItem}>
                <Text style={styles.highlight}>无财产价值</Text>
                {"\n"}虚拟物品不具备现实货币价值，我们不认可任何虚拟物品与真实货币之间的兑换关系。
              </Text>
            </View>

            <Text style={styles.subTitle}>2.3 服务终止的影响</Text>
            <Text style={styles.text}>用户理解并同意：</Text>
            <Text style={styles.bullet}>• 当游戏服务终止（包括但不限于运营商决定停止运营、服务器关闭等）时，用户对虚拟物品的使用许可同时终止。</Text>
            <Text style={styles.bullet}>• 用户<Text style={styles.highlight}>无权要求</Text>因服务终止而获得任何形式的补偿、赔偿或退款。</Text>
            <Text style={styles.bullet}>• 虚拟物品数据将在服务终止后被删除，且无法恢复。</Text>
          </View>

          {/* 3. 用户行为规范 */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>3. 用户行为规范</Text>

            <Text style={styles.subTitle}>3.1 禁止行为</Text>
            <Text style={styles.text}>用户在使用本游戏时，不得从事以下行为：</Text>
            <Text style={styles.bullet}>• 利用游戏漏洞、Bug进行作弊</Text>
            <Text style={styles.bullet}>• 使用外挂、脚本、修改器等第三方工具</Text>
            <Text style={styles.bullet}>• 传播病毒、恶意代码</Text>
            <Text style={styles.bullet}>• 骚扰、辱骂其他玩家</Text>
            <Text style={styles.bullet}>• 发布违法、有害、虚假信息</Text>
            <Text style={styles.bullet}>• 试图攻击、入侵游戏服务器</Text>
            <Text style={styles.bullet}>• 销售、购买游戏账号或虚拟物品（现实货币交易）</Text>

            <Text style={styles.subTitle}>3.2 违规处理</Text>
            <Text style={styles.text}>对于违反用户行为规范的用户，我们有权采取以下措施：</Text>
            <Text style={styles.bullet}>• 警告</Text>
            <Text style={styles.bullet}>• 暂时或永久封禁账号</Text>
            <Text style={styles.bullet}>• 删除违规内容</Text>
            <Text style={styles.bullet}>• 追究法律责任</Text>
          </View>

          {/* 4. 知识产权 */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>4. 知识产权</Text>
            <Text style={styles.text}>
              本游戏的所有内容，包括但不限于：
            </Text>
            <Text style={styles.bullet}>• 游戏软件、源代码</Text>
            <Text style={styles.bullet}>• 游戏画面、音效、音乐</Text>
            <Text style={styles.bullet}>• 游戏文字、剧情、对话</Text>
            <Text style={styles.bullet}>• 游戏logo、图标、界面设计</Text>
            <Text style={styles.bullet}>• 以上内容的衍生作品</Text>
            <Text style={styles.text}>
              其知识产权均归 WAPMUD 或其授权方所有，受中国法律及相关国际条约保护。
            </Text>
            <Text style={styles.text}>
              用户仅享有为个人娱乐目的使用本游戏的权利，不得擅自复制、修改、传播、商业利用上述内容。
            </Text>
          </View>

          {/* 5. 免责声明 */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>5. 免责声明</Text>
            <Text style={styles.text}>在法律允许的最大范围内：</Text>
            <Text style={styles.bullet}>• 本游戏按"现状"提供，不提供任何明示或暗示的保证。</Text>
            <Text style={styles.bullet}>• 我们不对因使用本游戏而产生的任何直接或间接损失承担责任。</Text>
            <Text style={styles.bullet}>• 因不可抗力、网络故障、系统维护等原因导致的服务中断或数据丢失，我们不承担责任。</Text>
            <Text style={styles.bullet}>• 用户因违反本条款而导致的任何损失，由用户自行承担。</Text>
          </View>

          {/* 6. 服务变更与终止 */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>6. 服务变更与终止</Text>
            <Text style={styles.text}>我们保留以下权利：</Text>
            <Text style={styles.bullet}>• 修改游戏内容、规则、功能</Text>
            <Text style={styles.bullet}>• 暂停或终止全部或部分服务</Text>
            <Text style={styles.bullet}>• 合并或关闭游戏服务器</Text>
            <Text style={styles.bullet}>• 调整游戏收费模式（如适用）</Text>
            <Text style={styles.text}>
              如游戏服务终止，我们将提前在游戏内公告或网站通知（但因不可抗力导致的紧急终止除外）。
            </Text>
            <Text style={styles.text}>
              用户理解并同意：服务终止后，用户对虚拟物品的使用许可同时终止，用户无权要求任何补偿或赔偿。
            </Text>
          </View>

          {/* 7. 条款修改 */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>7. 条款修改</Text>
            <Text style={styles.text}>
              我们保留随时修改本服务条款的权利。修改后的条款将在本页面发布，并在游戏内通知用户。
            </Text>
            <Text style={styles.text}>
              如用户在条款修改后继续使用本游戏，即视为用户接受修改后的条款。
            </Text>
            <Text style={styles.text}>
              如用户不同意修改后的条款，应停止使用本游戏。
            </Text>
          </View>

          {/* 8. 法律适用与争议解决 */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>8. 法律适用与争议解决</Text>
            <Text style={styles.text}>
              本服务条款的订立、执行、解释及争议解决均适用中华人民共和国法律。
            </Text>
            <Text style={styles.text}>
              如就本条款产生争议，双方应友好协商解决；协商不成的，任何一方可向我们所在地人民法院提起诉讼。
            </Text>
          </View>

          <View style={styles.footer}>
            <Text style={styles.footerText}>← 返回游戏</Text>
            <Text style={styles.footerText}>© 2026 wapmud.com 版权所有</Text>
          </View>
        </ScrollView>
      </SafeAreaView>
    </View>
    
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f0c29',
  },
  safeArea: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#1a1a2e',
    borderBottomWidth: 1,
    borderBottomColor: '#333',
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#a855f7',
  },
  closeButton: {
    fontSize: 28,
    color: '#888',
    paddingHorizontal: 8,
  },
  content: {
    flex: 1,
  },
  contentContainer: {
    padding: 16,
    paddingBottom: 32,
  },
  updateDate: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
    marginBottom: 20,
  },
  section: {
    marginBottom: 20,
    backgroundColor: 'rgba(255, 255, 255, 0.03)',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(168, 85, 247, 0.2)',
  },
  warningSection: {
    backgroundColor: 'rgba(251, 191, 36, 0.1)',
    borderColor: 'rgba(251, 191, 36, 0.3)',
  },
  importantSection: {
    backgroundColor: 'rgba(239, 68, 68, 0.08)',
    borderColor: 'rgba(239, 68, 68, 0.4)',
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#a855f7',
    marginBottom: 12,
  },
  subTitle: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#fbbf24',
    marginTop: 12,
    marginBottom: 8,
  },
  warningTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#fbbf24',
    marginBottom: 8,
  },
  text: {
    fontSize: 14,
    color: '#ccc',
    lineHeight: 22,
    marginBottom: 8,
  },
  highlight: {
    color: '#fbbf24',
    fontWeight: 'bold',
  },
  bullet: {
    fontSize: 14,
    color: '#aaa',
    lineHeight: 22,
    marginLeft: 12,
    marginBottom: 4,
  },
  alertBox: {
    backgroundColor: 'rgba(239, 68, 68, 0.15)',
    borderRadius: 8,
    padding: 12,
    marginTop: 8,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: 'rgba(239, 68, 68, 0.4)',
  },
  alertTitle: {
    fontSize: 13,
    fontWeight: 'bold',
    color: '#fca5a5',
    marginBottom: 8,
  },
  alertItem: {
    fontSize: 13,
    color: '#eee',
    lineHeight: 20,
    marginBottom: 8,
  },
  footer: {
    marginTop: 20,
    paddingTop: 16,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255, 255, 255, 0.1)',
  },
  footerText: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
    marginBottom: 4,
  },
});
