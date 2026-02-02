import SwiftUI

struct ProfileSetupView: View {
    let phone: String
    let onComplete: (_ fullName: String, _ birthDate: Date, _ city: String) -> Void

    @State private var fullName: String = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var selectedCity: String = "Москва"

    private let cities: [String] = [
        "Москва", "Санкт-Петербург", "Новосибирск", "Екатеринбург", "Казань",
        "Нижний Новгород", "Челябинск", "Самара", "Омск", "Ростов-на-Дону",
        "Краснодар", "Уфа", "Красноярск", "Воронеж", "Пермь"
    ]

    private var canContinue: Bool {
        fullName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Анкета")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Номер: \(formatPhone(phone))")
                .foregroundColor(.secondary)

            TextField("ФИО", text: $fullName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(14)

            DatePicker("Дата рождения", selection: $birthDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(14)

            VStack(alignment: .leading, spacing: 8) {
                Text("Город проживания")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Город", selection: $selectedCity) {
                    ForEach(cities, id: \.self) { city in
                        Text(city).tag(city)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(14)
            }

            Button("Сохранить и продолжить") {
                onComplete(
                    fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                    birthDate,
                    selectedCity
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.5)

            Spacer()
        }
        .padding(.horizontal)
    }

    private func formatPhone(_ digits: String) -> String {
        // просто красивый вывод, без строгого форматтера
        return "+\(digits)"
    }
}

#Preview {
    ProfileSetupView(phone: "79991234567", onComplete: { _,_,_ in })
}
