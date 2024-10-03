//
//  ContentView.swift
//  AutoCalendar
//
//  Created by 周玮琦 on 10/3/24.
//


import SwiftUI
import EventKit

import SwiftUI
import EventKit

struct Day: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var isSelected: Bool
}

struct ContentView: View {
    // State variables
    @State private var courseName: String = ""
    @State private var location: String = ""
    @State private var instructor: String = ""
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var daysOfWeek: [Day] = [
        Day(name: "Sun", isSelected: false),
        Day(name: "Mon", isSelected: false),
        Day(name: "Tue", isSelected: false),
        Day(name: "Wed", isSelected: false),
        Day(name: "Thu", isSelected: false),
        Day(name: "Fri", isSelected: false),
        Day(name: "Sat", isSelected: false)
    ]
    @State private var semesterEndDate = Date()
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Course Details")) {
                    TextField("Course Name", text: $courseName)
                    TextField("Location", text: $location)
                    TextField("Instructor", text: $instructor)
                }

                Section(header: Text("Time")) {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                Section(header: Text("Days")) {
                    HStack(spacing: 5) {
                        ForEach($daysOfWeek) { $day in
                            Button(action: {
                                day.isSelected.toggle()
                            }) {
                                Text(day.name)
                                    .font(.system(size: 14))
                                    .foregroundColor(day.isSelected ? .white : .blue)
                                    .frame(width: 35, height: 35)
                                    .background(day.isSelected ? Color.blue : Color.clear)
                                    .cornerRadius(5)
                            }
                        }
                    }
                }

                Section(header: Text("Semester End Date")) {
                    DatePicker("End Date", selection: $semesterEndDate, displayedComponents: .date)
                }

                Button(action: {
                    addCourseToCalendar()
                }) {
                    Text("Add Course to Calendar")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Add Course")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Info"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    // Updated function to request calendar access
    func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        let eventStore = EKEventStore()
        
        if #available(iOS 17.0, *) {
            // For iOS 17 and later
            eventStore.requestWriteOnlyAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            // For iOS versions earlier than 17
            eventStore.requestAccess(to: .event) { (granted, error) in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }

    func addCourseToCalendar() {
        requestCalendarAccess { (granted) in
            if granted {
                let eventStore = EKEventStore()
                let event = EKEvent(eventStore: eventStore)

                event.title = courseName
                event.location = location

                // Set the start and end dates
                let calendar = Calendar.current
                var startComponents = calendar.dateComponents([.year, .month, .day], from: Date())
                startComponents.hour = calendar.component(.hour, from: startTime)
                startComponents.minute = calendar.component(.minute, from: startTime)

                var endComponents = startComponents
                endComponents.hour = calendar.component(.hour, from: endTime)
                endComponents.minute = calendar.component(.minute, from: endTime)

                guard let eventStartDate = calendar.date(from: startComponents),
                      let eventEndDate = calendar.date(from: endComponents) else {
                    self.alertMessage = "Failed to create event dates."
                    self.showAlert = true
                    return
                }

                event.startDate = eventStartDate
                event.endDate = eventEndDate
                event.calendar = eventStore.defaultCalendarForNewEvents

                // Recurrence Rule
                let selectedDaysIndices = daysOfWeek.enumerated().compactMap { index, day -> EKRecurrenceDayOfWeek? in
                    if day.isSelected, let weekday = EKWeekday(rawValue: index + 1) {
                        return EKRecurrenceDayOfWeek(weekday)
                    } else {
                        return nil
                    }
                }

                if selectedDaysIndices.isEmpty {
                    DispatchQueue.main.async {
                        self.alertMessage = "Please select at least one day."
                        self.showAlert = true
                    }
                    return
                }

                if eventEndDate <= eventStartDate {
                    DispatchQueue.main.async {
                        self.alertMessage = "End time must be after start time."
                        self.showAlert = true
                    }
                    return
                }

                let recurrenceRule = EKRecurrenceRule(
                    recurrenceWith: .weekly,
                    interval: 1,
                    daysOfTheWeek: selectedDaysIndices,
                    daysOfTheMonth: nil,
                    monthsOfTheYear: nil,
                    weeksOfTheYear: nil,
                    daysOfTheYear: nil,
                    setPositions: nil,
                    end: EKRecurrenceEnd(end: semesterEndDate)
                )
                event.addRecurrenceRule(recurrenceRule)

                // Save the event
                do {
                    try eventStore.save(event, span: .thisEvent)
                    DispatchQueue.main.async {
                        self.alertMessage = "Course added to your calendar!"
                        self.showAlert = true
                    }
                } catch let error as NSError {
                    DispatchQueue.main.async {
                        self.alertMessage = "Failed to save event: \(error.localizedDescription)"
                        self.showAlert = true
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.alertMessage = "Calendar access denied."
                    self.showAlert = true
                }
            }
        }
    }
}


#Preview {
    ContentView()
}
