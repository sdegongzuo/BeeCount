//
//  BeeCountWidget.swift
//  BeeCountWidget
//
//  Created by matrix on 2025/11/5.
//

import WidgetKit
import SwiftUI

struct BeeCountEntry: TimelineEntry {
    let date: Date
    let widgetImagePath: String
}

struct BeeCountProvider: TimelineProvider {
    func placeholder(in context: Context) -> BeeCountEntry {
        BeeCountEntry(
            date: Date(),
            widgetImagePath: ""
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BeeCountEntry) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: "widgetImage") ?? ""
        let entry = BeeCountEntry(date: Date(), widgetImagePath: imagePath)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: "widgetImage") ?? ""
        let entry = BeeCountEntry(date: Date(), widgetImagePath: imagePath)

        // 设置30分钟后刷新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct BeeCountWidgetEntryView : View {
    var entry: BeeCountProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    private let expenseURL = URL(string: "beecount://new?type=expense")!
    private let incomeURL = URL(string: "beecount://new?type=income")!

    var body: some View {
        if let uiImage = UIImage(contentsOfFile: entry.widgetImagePath) {
            return AnyView(
                GeometryReader { geometry in
                    ZStack {
                        // 底层：渲染的小组件图片
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()

                        // 上层：透明点击区域（左侧支出，右侧收入）
                        VStack(spacing: 0) {
                            // 跳过 header 区域（约占总高度 30%）
                            Color.clear
                                .frame(height: geometry.size.height * 0.28)

                            // 数据区域分为左右两栏
                            HStack(spacing: 0) {
                                Link(destination: expenseURL) {
                                    Color.clear
                                }
                                Link(destination: incomeURL) {
                                    Color.clear
                                }
                            }
                        }
                    }
                }
            )
        } else {
            return AnyView(
                // Placeholder view when image is not available
                ZStack {
                    Color(red: 1.0, green: 0.76, blue: 0.03)
                    VStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                        Text("蜜蜂记账")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .widgetURL(expenseURL)
            )
        }
    }
}

struct BeeCountWidget: Widget {
    let kind: String = "BeeCountWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BeeCountProvider()) { entry in
            if #available(iOS 17.0, *) {
                BeeCountWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                BeeCountWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("蜜蜂记账")
        .description("显示今日和本月的收支情况")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()  // Remove default padding/margins in iOS 17+
    }
}
