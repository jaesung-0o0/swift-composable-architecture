import ComposableArchitecture

@Reducer
struct SyncUpDetail {
  // ...
}

struct SyncUpDetailView {
  @Bindable var store: StoreOf<SyncUpDetail>

  var body: some View {
    Form {
      Section {
        Button {
          store.send(.startMeetingButtonTapped)
        } label: {
          Label("Start Meeting", systemImage: "timer")
            .font(.headline)
            .foregroundColor(.accentColor)
        }
        HStack {
          Label("Length", systemImage: "clock")
          Spacer()
          Text(store.syncUp.duration.formatted(.units()))
        }

        HStack {
          Label("Theme", systemImage: "paintpalette")
          Spacer()
          Text(store.syncUp.theme.name)
            .padding(4)
            .foregroundColor(store.syncUp.theme.accentColor)
            .background(store.syncUp.theme.mainColor)
            .cornerRadius(4)
        }
      } header: {
        Text("Sync-up Info")
      }

      if !store.syncUp.meetings.isEmpty {
        Section {
          ForEach(store.syncUp.meetings) { meeting in
            Button {
              store.send(.meetingTapped(id: meeting.id))
            } label: {
              HStack {
                Image(systemName: "calendar")
                Text(meeting.date, style: .date)
                Text(meeting.date, style: .time)
              }
            }
          }
          .onDelete { indices in
            store.send(.deleteMeetings(atOffsets: indices))
          }
        } header: {
          Text("Past meetings")
        }
      }

      Section {
        ForEach(store.syncUp.attendees) { attendee in
          Label(attendee.name, systemImage: "person")
        }
      } header: {
        Text("Attendees")
      }

      Section {
        Button("Delete") {
          store.send(.deleteButtonTapped)
        }
        .foregroundColor(.red)
        .frame(maxWidth: .infinity)
      }
    }
    .toolbar {
      Button("Edit") {
        store.send(.editButtonTapped)
      }
    }
    .sheet(item: $store.scope(state: \.editSyncUp, action: \.editSyncUp)) { store in
      NavigationStack {
        SyncUpFormView(store: store)
          .navigationTitle(store.syncUp.title)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") {
                store.send(.cancelEditButtonTapped)
              }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") {
                store.send(.doneEditingButtonTapped)
              }
            }
          }
      }
  }
}

#Preview {
  SyncUpDetailView(
    store: Store(
      initialState: SyncUpDetail.State(
        syncUp: SyncUp(
          syncUp: SyncUp(
            id: SyncUp.ID(),
            attendees: [
              Attendee(id: Attendee.ID(), name: "Blob"),
              Attendee(id: Attendee.ID(), name: "Blob Jr."),
              Attendee(id: Attendee.ID(), name: "Blob Sr."),
            ],
            title: "Point-Free Morning Sync"
          )
        )
      )
    ) {
      SyncUpDetail()
    }
  )
}