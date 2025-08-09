import SwiftUI

@available(tvOS 17.0, *)
struct JellyfinSortSelectionPopoverTV: View {
    @Binding var isPresented: Bool
    @Binding var selectedOption: JellyfinMediaLibraryView.SortOption
    @FocusState private var focusedOption: JellyfinMediaLibraryView.SortOption?
    @Namespace private var focusNamespace

    var body: some View {
        ZStack {
            backgroundOverlay
            mainContent
        }
        .scaleEffect(isPresented ? 1 : 0.8)
        .opacity(isPresented ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: isPresented)
        .onAppear {
            focusedOption = selectedOption
        }
    }
    
    private var backgroundOverlay: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .onTapGesture {
                isPresented = false
            }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            optionsList
        }
        .frame(width: 660)
        .background(popoverBackground)
        .focusScope(focusNamespace)
    }
    
    private var headerView: some View {
        HStack {
            Text("排序方式")
                .font(.largeTitle)
                .fontWeight(.bold)
            Spacer()
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .opacity(0.7)
            }
            .buttonStyle(.plain)
            .focusable()
        }
        .padding()
    }
    
    private var optionsList: some View {
        VStack(spacing: 8) {
            ForEach(JellyfinMediaLibraryView.SortOption.allCases, id: \.self) { option in
                optionButton(for: option)
            }
        }
        .padding()
    }
    
    private func optionButton(for option: JellyfinMediaLibraryView.SortOption) -> some View {
        Button {
            selectedOption = option
            isPresented = false
        } label: {
            HStack {
                Text(option.rawValue)
                    .font(.title2)
                    .opacity(selectedOption == option ? 1 : 0.8)
                Spacer()
                if selectedOption == option {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(focusedOption == option ? Color.accentColor.opacity(0.3) : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .focused($focusedOption, equals: option)
    }
    
    private var popoverBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.black.opacity(0.9))
            .shadow(radius: 20)
    }
}
