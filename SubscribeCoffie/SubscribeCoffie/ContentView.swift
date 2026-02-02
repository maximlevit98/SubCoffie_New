//
//  ContentView.swift
//  SubscribeCoffie
//
//  Created by Максим on 07.01.2026.
//
import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct ContentView: View {
    
    // MARK: - Экраны приложения
    enum AppScreen {
        case onboarding
        case map
        case cafe
        case confirmation
    }
    
    // MARK: - State
    @State private var isLoading = true
    @State private var currentScreen: AppScreen = .onboarding
    @State private var selectedPlan: Int? = nil
    @State private var isSubscriptionExpanded = true
    @State private var isMenuExpanded = false
    @State private var isCafeInfoExpanded = false
    @State private var isQrPresented = false
    @State private var isProfilePresented = false


    
    let plans = [5, 10, 15]
    
    private var shouldShowQrBar: Bool {
        !isLoading && currentScreen != .onboarding
    }
    // MARK: - Top Bar conditions

    private var shouldShowTopBar: Bool {
        !isLoading
    }

    private var canGoBack: Bool {
        switch currentScreen {
        case .onboarding:
            return false
        case .map, .cafe, .confirmation:
            return true
        }
    }

    private var topBarTitle: String {
        switch currentScreen {
        case .onboarding:   return "SubscribeCoffie"
        case .map:          return "Выбор кофейни"
        case .cafe:         return "Coffee Point"
        case .confirmation: return "Подтверждение"
        }
    }

    private func handleBack() {
        switch currentScreen {
        case .onboarding:
            break

        case .map:
            currentScreen = .onboarding

        case .cafe:
            currentScreen = .map
            selectedPlan = nil
            isCafeInfoExpanded = false
            isMenuExpanded = false
            isSubscriptionExpanded = true

        case .confirmation:
            currentScreen = .cafe
        }
    }
    // MARK: - Top Bar UI

    private var topBar: some View {
        HStack(spacing: 12) {

            // Левая кнопка: Назад (только когда можно)
            if canGoBack {
                Button {
                    handleBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Назад")
                    }
                }
                .buttonStyle(.plain)
            } else {
                // чтобы заголовок визуально не "уезжал"
                Color.clear.frame(width: 60, height: 1)
            }

            Spacer()

            Text(topBarTitle)
                .font(.headline)

            Spacer()

            // Правая кнопка: Профиль
            Button {
                isProfilePresented = true
            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }

    
    // MARK: - Body
    var body: some View {
        VStack {
            if isLoading {
                // Стартовая загрузка
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Загружаем приложение…")
                    .padding(.top, 16)
                
            } else {
                switch currentScreen {
                case .onboarding:
                    onboardingView
                case .map:
                    mapSelectionView
                case .cafe:
                    cafeView
                case .confirmation:
                    confirmationView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal)
        .onAppear {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isLoading = false
            }
        }
        .safeAreaInset(edge: .top) {
            if shouldShowTopBar {
                topBar
            }
        }
        .sheet(isPresented: $isProfilePresented) {
            profileSheetView
        }
        .safeAreaInset(edge: .bottom) {
            if shouldShowQrBar {
                qrBottomBar
            }
        }
        .sheet(isPresented: $isQrPresented) {
            qrSheet
        }

    }
    
    // MARK: - Onboarding
    
    var onboardingView: some View {
        VStack(spacing: 24) {
            Text("Подписка на кофе ☕️")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Выберите любимую кофейню на карте и оформите подписку за пару шагов.")
                .multilineTextAlignment(.center)

            Button("Выбрать кофейню") {
                currentScreen = .map
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Экран выбора кофейни
    
    var mapSelectionView: some View {
        VStack(spacing: 16) {
            
            Text("Выберите кофейню")
                .font(.title)
                .fontWeight(.semibold)
            
            // Картинка кофейни (по нажатию — "О кофейне")
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.brown.opacity(0.2))
                    .frame(height: 200)

                Image(systemName: "cup.and.saucer.fill")
                    .font(.largeTitle)
                    .foregroundColor(.brown)
            }
            
            Button("Выбрать эту кофейню") {
                isCafeInfoExpanded = false
                currentScreen = .cafe
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Страница кофейни + подписки
    
    var cafeView: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: - Hero кофейни
                VStack(alignment: .leading, spacing: 16) {
                    Text("Coffee Point ☕️")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    // Картинка кофейни (заглушка)
                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            isCafeInfoExpanded.toggle()
                        }
                    } label: {
                        cafeHeroFlipCard(isFlipped: isCafeInfoExpanded)
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                

                // MARK: - Меню кофейни
                VStack(spacing: 12) {
                    cafeMenuItem(
                        title: "Подписка",
                        subtitle: "Выбрать тариф и оформить подписку",
                        icon: "creditcard.fill",
                        isPrimary: true
                    ) {
                        withAnimation {
                            isSubscriptionExpanded.toggle()
                        }
                    }

                    cafeMenuItem(
                        title: "Меню напитков",
                        subtitle: "Посмотреть ассортимент",
                        icon: "menucard.fill",
                        isPrimary: false
                    ) {
                        // позже
                    }
                }
                .padding()

                // MARK: - Блок подписки (раскрытый)
                if isSubscriptionExpanded {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Выберите подписку")
                            .font(.headline)

                        VStack(spacing: 12) {
                            ForEach(plans, id: \.self) { plan in
                                subscriptionOption(price: plan)
                            }
                        }

                        Button("Продолжить") {
                            currentScreen = .confirmation
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedPlan == nil)
                        .opacity(selectedPlan == nil ? 0.5 : 1)
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Пункт меню кофейни

    func cafeMenuItem(
        title: String,
        subtitle: String,
        icon: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isPrimary ? .white : .accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundColor(isPrimary ? .white : .primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(isPrimary ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(isPrimary ? .white.opacity(0.8) : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isPrimary ? Color.accentColor : Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero flip card
    @ViewBuilder
    func cafeHeroFlipCard(isFlipped: Bool) -> some View {
        ZStack {
            // Front side
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.brown.opacity(0.2))
                Image(systemName: "cup.and.saucer.fill")
                    .font(.largeTitle)
                    .foregroundColor(.brown)
            }
            .opacity(isFlipped ? 0 : 1)

            // Back side
            VStack(alignment: .leading, spacing: 8) {
                Text("О кофейне")
                    .font(.headline)

                Text("Уютная кофейня рядом с вами. Здесь можно будет разместить адрес, часы работы, описание и фотографии.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("Нажмите, чтобы вернуться к фото")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
            )
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(height: 200)
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }
    
    // MARK: - Profile Sheet

    private var profileSheet: some View {
        VStack(spacing: 16) {
            Text("Личный кабинет")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Имя").foregroundColor(.secondary)
                    Spacer()
                    Text("Пользователь")
                }
                HStack {
                    Text("Подписка").foregroundColor(.secondary)
                    Spacer()
                    Text(selectedPlan == nil ? "не выбрана" : "$\(selectedPlan!) / месяц")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(14)

            Button("Закрыть") {
                isProfilePresented = false
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    
    // MARK: - Экран подтверждения подписки
    
    var confirmationView: some View {
        VStack(spacing: 20) {
            Text("Подтверждение подписки ☕️")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Coffee Point")
                .font(.headline)
            
            if let plan = selectedPlan {
                Text("$\(plan) / месяц")
                    .font(.title)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("Что входит в подписку:")
                    .font(.headline)
                
                Text("""
• Любимый кофе каждый день
• Без очередей
• Фиксированная цена
• Можно отменить в любой момент
""")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            }
            
            Button("Подтвердить") {
                // здесь будет оплата / финал
            }
            .buttonStyle(.borderedProminent)
        }
    }
    // MARK: - Profile (Личный кабинет)

    private var profileButton: some View {
        Button {
            isProfilePresented = true
        } label: {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var profileSheetView: some View {
        VStack(spacing: 16) {
            Text("Личный кабинет")
                .font(.title2)
                .fontWeight(.bold)

            // Заглушка профиля (позже заменим реальными данными)
            VStack(alignment: .leading, spacing: 10) {
                infoRow(title: "Имя", value: "Максим")
                infoRow(title: "Телефон", value: "+7 (___) ___-__-__")
                infoRow(title: "Статус подписки", value: selectedPlan == nil ? "не выбрана" : "выбрана: $\(selectedPlan!) / месяц")
                infoRow(title: "Кофейня", value: "Coffee Point")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(14)

            Button("Закрыть") {
                isProfilePresented = false
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - QR Bar

    private var qrPayload: String {
        // пока статично; позже можно добавить cafe/plan/user
        if let plan = selectedPlan {
            return "SubscribeCoffie|cafe=Coffee Point|plan=\(plan)"
        }
        return "SubscribeCoffie|cafe=Coffee Point"
    }

    private var qrBottomBar: some View {
        HStack {
            Spacer()

            Button {
                isQrPresented = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)

                    Text("QR")
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var qrSheet: some View {
        VStack(spacing: 16) {
            Text("Ваш QR-код")
                .font(.title2)
                .fontWeight(.bold)

            Image(uiImage: generateQRCode(from: qrPayload))
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 240, height: 240)

            Text(qrPayload)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Закрыть") {
                isQrPresented = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Элемент подписки
    
    func subscriptionOption(price: Int) -> some View {
        Button {
            selectedPlan = price
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text("$\(price) / месяц")
                        .font(.headline)
                    Text("Подписка на кофе")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if selectedPlan == price {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selectedPlan == price ? Color.green : Color.gray.opacity(0.3),
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Кнопка назад
    
    func backButton(action: @escaping () -> Void) -> some View {
        HStack {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Назад")
                }
            }

            Spacer()

            Button {
                isProfilePresented = true
            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
    }

    
    // MARK: - QR Code Generation
    private func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        // Optional: increase error correction level (L, M, Q, H). Defaults to M if not set.
        // filter.setValue("M", forKey: "inputCorrectionLevel")

        if let outputImage = filter.outputImage {
            // Scale the CIImage to a higher resolution for clarity
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)

            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        // Fallback placeholder if generation fails
        return UIImage(systemName: "xmark.octagon") ?? UIImage()
    }
}

#Preview {
    ContentView()
}
