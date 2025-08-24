//
//  MenuView.swift
//  RAZN NFC
//
//  Created by Habibur Rahman on 9/8/25.
//

import SwiftUI

struct MenuView: View {
    @StateObject var vm = MenuVM()
    @EnvironmentObject var nfcWriteInfoVM: NFCWriteInfoVM
    @StateObject private var nfcReader = NFCReader()

    @Binding var path: [Screens]
    @State private var showAlert = false

    @State private var items = ["Alpha"]

    var body: some View {
        ZStack {
            mainSection

        }.background {
            CustomBG()
        }.onAppear{
            UITableView.appearance().backgroundColor = .clear
        }
       
        .alert("Oops!",
               isPresented: $showAlert) {
            Button("ok", role: .cancel) { }
        } message: {
            Text("You need to insert a valid link.")
        }
        .navigationBarBackButtonHidden(true)
    }

    private func scanTag() {
        nfcReader.scan { payload in
            print("U>> Scaned data \(payload)")
        }
    }

    private func writeTag(text: String) {
        nfcReader.write(text, completion: { isSuccess in
            print("U>> write isSuccess \(isSuccess)")

            if text.isValidURLString() {
                print("Valid Url")
                writeTag(text: nfcWriteInfoVM.getfullURL())
            } else {
                print("inValid Url")
            }

        })
    }

    func getWriteBytesText() -> String {
        if nfcWriteInfoVM.isUrlInserted() == false {
            return "WRITE"
        }

        return "WRITE / " + nfcWriteInfoVM.getfullURL().getBytesString()
    }
}

#Preview {
    MenuView(path: .constant([]))
        .environmentObject(NFCWriteInfoVM())
}

extension MenuView {
    var mainSection: some View {
        VStack {
            TopBarView(mainTitle: "write", leftBtnTitle: "Menu", rightBtnTitle: "edit")
            //  .background(.black)

            VStack {
                Button(action: {
                    // vm.gotoAddFieled = true
                    path.append(.AddField)

                }) {
                    ZStack {
                        Image("glass_capsule")
                            .resizable()
                            .frame(height: 80)

                        HStack {
                            Image(systemName: "plus.circle")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.white)
                                .padding(.leading, 30)

                            Spacer()

                            Text("ADD FIELD")
                                .font(.custom(Constants.Fonts.cgoogla, size: 20))
                                .foregroundStyle(.white.opacity(0.8))
                                .offset(x: -30, y: 2)
                            Spacer()
                        }
                    }
                }

                Button(action: {
                    if nfcWriteInfoVM.isUrlInserted() == false {
                        showAlert = true
                    } else {
                        writeTag(text: nfcWriteInfoVM.getfullURL())
                    }

                }) {
                    ZStack {
                        Image("glass_capsule")
                            .resizable()
                            .frame(height: 80)

                        HStack {
                            Image(systemName: "person.wave.2")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundStyle(.white)
                                .padding(.leading, 30)

                            Spacer()

                            Text(getWriteBytesText())
                                .font(.custom(Constants.Fonts.cgoogla, size: 20))
                                .foregroundStyle(.white.opacity(0.8))
                                .offset(x: -30, y: 2)
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 30)

//            if nfcWriteInfoVM.isUrlInserted() {
//                
//                
//                
//                URLFieldButtonView()
//                    .frame(height: 100)
//                // .padding(.horizontal,20)
//            }

            listView

            Spacer()
        }
    }

    var listView: some View {
        List {
            ForEach(nfcWriteInfoVM.getInsertedURLS().indices, id: \.self) { i in
                HStack {
                    URLFieldButtonView(hasGlassBG: false)
                }
                .contentShape(Rectangle()) // keep full-row tap/swipe area
                   
                .listRowBackground(Color.white.opacity(0.01))
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) // ⬅️ remove padding
                .padding(.vertical, 0) // ensure no extra vertical padding from your content
                   
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        //  deleteItem(at: i)
                        nfcWriteInfoVM.removeInsertedURL()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }.padding(10)

                    Button {
                        // startEdit(i)
                        path.append(.AddUrl)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.clear)
                }
            }
            
            
        }
       
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 0) // let rows shrink to content height
    
      //  .background(Color.green)
       // .scrollContentBackground(.hidden) // hide List’s default white bg
             //    .background(Color.clear)          // keep our ZStack color visible
             
    }
}
