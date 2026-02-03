import SwiftUI
import AppKit

struct ProviderCard: View {
    let provider: AIProvider
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    // Fallback to system icon if custom asset is not found
                    if let _ = NSImage(named: provider.icon) {
                        Image(provider.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: provider.systemIcon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(isSelected ? .white : .blue)
                    }
                }
                
                VStack(spacing: 4) {
                    Text(provider.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.primary.opacity(0.8)))
                    
                    Text(provider.description)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.secondary) : AnyShapeStyle(.secondary.opacity(0.7)))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
