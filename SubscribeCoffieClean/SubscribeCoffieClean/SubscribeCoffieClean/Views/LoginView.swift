//
//  LoginView.swift (Stub)
//  SubscribeCoffieClean
//
//  Temporary stub for LoginView
//

import SwiftUI

struct LoginView: View {
    let onSuccess: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("SubscribeCoffie")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Вход временно отключен")
                .foregroundColor(.secondary)
            
            Button(action: {
                // Временно пропускаем авторизацию
                onSuccess()
            }) {
                Text("Продолжить без входа")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}
