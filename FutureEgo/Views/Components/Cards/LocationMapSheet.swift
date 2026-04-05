import SwiftUI
import MapKit

// MARK: - LocationMapSheet
//
// Shared bottom sheet used by OutingCard, EatOutCard, and ExercisingCard to
// display the location of a destination / restaurant / venue. When a
// `GeoPoint` coordinate is available it renders a MapKit `Map` view with a
// single pin; otherwise it falls back to a text-only address card.

struct LocationMapSheet: View {
    let title: String
    let address: String
    let coordinate: GeoPoint?
    var onClose: (() -> Void)? = nil

    // MARK: - Design tokens
    private let grayText = Color(hex: "8E8E93")
    private let darkText = Color(hex: "3A3A3C")

    @State private var cameraPosition: MapCameraPosition

    init(
        title: String,
        address: String,
        coordinate: GeoPoint?,
        onClose: (() -> Void)? = nil
    ) {
        self.title = title
        self.address = address
        self.coordinate = coordinate
        self.onClose = onClose

        // Initialize the camera to the coordinate if we have one, else Beijing.
        let fallback = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        let initial = coordinate?.coordinate ?? fallback
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: initial,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.black.opacity(0.15))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 4)

            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                    if !address.isEmpty {
                        Text(address)
                            .font(.system(size: 13))
                            .foregroundColor(grayText)
                            .lineLimit(2)
                    }
                }
                Spacer()
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(darkText)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.black.opacity(0.06)))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Divider()

            // Map or fallback
            if let coordinate {
                Map(position: $cameraPosition) {
                    Marker(title, coordinate: coordinate.coordinate)
                        .tint(Color.brandGreen)
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                addressFallback
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Fallback when no coordinate

    private var addressFallback: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 44))
                .foregroundColor(Color.brandGreen.opacity(0.5))
            Text(address.isEmpty ? "暂无地址信息" : address)
                .font(.system(size: 15))
                .foregroundColor(darkText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Text("未提供坐标,无法在地图上定位")
                .font(.system(size: 12))
                .foregroundColor(grayText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("With Coordinate") {
    LocationMapSheet(
        title: "国贸大厦三层会议室 A",
        address: "北京市朝阳区建国门外大街 1 号",
        coordinate: GeoPoint(latitude: 39.9080, longitude: 116.4640)
    )
}

#Preview("Address only") {
    LocationMapSheet(
        title: "未知地点",
        address: "北京市朝阳区某条街 100 号",
        coordinate: nil
    )
}
