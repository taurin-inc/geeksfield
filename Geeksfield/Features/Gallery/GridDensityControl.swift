import SwiftUI

struct GridDensityControl: View {
    @Binding var columns: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.grid.2x2")
                .foregroundStyle(.secondary)
            Stepper(value: $columns, in: 2...8) {
                Text("\(columns)")
                    .monospacedDigit()
                    .frame(minWidth: 20)
            }
            .labelsHidden()
        }
    }
}
