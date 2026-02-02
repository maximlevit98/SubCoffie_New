//
//  OrderHistoryView.swift (Stub)
//  SubscribeCoffieClean
//
//  Temporary stub for OrderHistoryView
//

import SwiftUI

struct OrderHistoryView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "clock.arrow.circlepath")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.secondary)
                
                Text("История заказов")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("История заказов временно недоступна")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
            .navigationTitle("История")
        }
    }
}
