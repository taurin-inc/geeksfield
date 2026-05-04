import SwiftUI

struct GridDensityControl: View {
    @Binding var columns: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.grid.2x2")
                .foregroundStyle(.secondary)

            Text("\(columns)")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 14)

            Stepper(value: $columns, in: 3...6) {
                EmptyView()
            }
            .labelsHidden()
        }
    }
}
