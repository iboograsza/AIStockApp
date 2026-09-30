import SwiftUI

struct SettingsView: View {
    @State private var apiKey = UserDefaults.standard.string(forKey: "deepseek_api_key") ?? ""
    @State private var showAPIKey = false
    @State private var toastMessage: String?
    @State private var showToast = false
    @State private var refreshInterval = UserDefaults.standard.integer(forKey: "refresh_interval") == 0
        ? 10 : UserDefaults.standard.integer(forKey: "refresh_interval")

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                Form {
                    // MARK: AI Configuration
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.red)
                                Text("DeepSeek API Key")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }

                            HStack {
                                Group {
                                    if showAPIKey {
                                        TextField("sk-...", text: $apiKey)
                                    } else {
                                        SecureField("sk-...", text: $apiKey)
                                    }
                                }
                                .foregroundColor(.white)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                                .autocorrectionDisabled()

                                Button(action: { showAPIKey.toggle() }) {
                                    Image(systemName: showAPIKey ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.gray)
                                }
                            }

                            HStack(spacing: 8) {
                                Button(action: saveAPIKey) {
                                    HStack {
                                        Image(systemName: "checkmark")
                                        Text("保存")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(apiKey.isEmpty ? Color.gray : Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(apiKey.isEmpty)

                                Button(action: testAPIKey) {
                                    HStack {
                                        Image(systemName: "network")
                                        Text("测试")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color(white: 0.2))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(apiKey.isEmpty)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("AI 设置")
                    }
                    .listRowBackground(Color(white: 0.1))

                    // MARK: How to get API key
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("如何获取 DeepSeek API Key")
                                .font(.subheadline)
                                .foregroundColor(.white)

                            ForEach([
                                "1. 访问 platform.deepseek.com",
                                "2. 注册账号并充值（极低价格）",
                                "3. 在 API Keys 页面创建新密钥",
                                "4. 将密钥粘贴到上方输入框"
                            ], id: \.self) { step in
                                Text(step)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Link("前往 DeepSeek 平台 →",
                                 destination: URL(string: "https://platform.deepseek.com")!)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("使用帮助")
                    }
                    .listRowBackground(Color(white: 0.1))

                    // MARK: Data Settings
                    Section {
                        HStack {
                            Text("刷新间隔")
                                .foregroundColor(.gray)
                            Spacer()
                            Picker("", selection: $refreshInterval) {
                                Text("5秒").tag(5)
                                Text("10秒").tag(10)
                                Text("30秒").tag(30)
                                Text("60秒").tag(60)
                            }
                            .pickerStyle(.menu)
                            .accentColor(.red)
                            .onChange(of: refreshInterval) { v in
                                UserDefaults.standard.set(v, forKey: "refresh_interval")
                            }
                        }
                        .listRowBackground(Color(white: 0.1))

                        HStack {
                            Text("数据来源")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("东方财富 · 新浪财经")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                        .listRowBackground(Color(white: 0.1))
                    } header: {
                        Text("数据设置")
                    }

                    // MARK: App Info
                    Section {
                        InfoRow(label: "版本", value: "1.0.0")
                        InfoRow(label: "AI 模型", value: "DeepSeek-V3")
                        InfoRow(label: "适用市场", value: "A股 · 沪深京")
                    } header: {
                        Text("关于")
                    }
                    .listRowBackground(Color(white: 0.1))

                    // MARK: Disclaimer
                    Section {
                        Text("⚠️ 本应用提供的所有分析结果仅供参考，不构成投资建议。股市有风险，投资需谨慎。请遵守相关法律法规，理性投资。")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineSpacing(3)
                    } header: {
                        Text("免责声明")
                    }
                    .listRowBackground(Color(white: 0.08))
                }
                .scrollContentBackground(.hidden)

                // Toast notification
                if showToast, let msg = toastMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(white: 0.2))
                            .cornerRadius(20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        Spacer().frame(height: 80)
                    }
                    .animation(.spring(), value: showToast)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
    }

    private func saveAPIKey() {
        DeepSeekService.shared.apiKey = apiKey
        showMessage("✅ API Key 已保存")
    }

    private func testAPIKey() {
        Task {
            showMessage("测试中...")
            do {
                let _ = try await DeepSeekService.shared.sendMessage([], userMessage: "请回复：测试成功")
                showMessage("✅ API Key 有效，连接成功")
            } catch let err as DeepSeekService.DeepSeekError {
                showMessage("❌ \(err.errorDescription ?? "测试失败")")
            } catch {
                showMessage("❌ 网络错误")
            }
        }
    }

    private func showMessage(_ msg: String) {
        toastMessage = msg
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showToast = false }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundColor(.gray)
            Spacer()
            Text(value).foregroundColor(.white)
        }
    }
}
