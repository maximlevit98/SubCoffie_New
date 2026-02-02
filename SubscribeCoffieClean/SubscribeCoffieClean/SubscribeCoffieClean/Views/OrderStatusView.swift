//
//  OrderStatusView.swift (Stub)
//  SubscribeCoffieClean
//
//  Temporary stub for OrderStatusView
//

import SwiftUI

struct OrderStatusView: View {
    let orderId: UUID
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.green)
            
            Text("Заказ оформлен!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("ID заказа:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(orderId.uuidString)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Text("Статус заказа временно недоступен")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
        }
        .padding()
    }
}
