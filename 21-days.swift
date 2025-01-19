//  ContentView.swift
//  Created by AMO on 25/12/2024.

import SwiftUI
import UserNotifications

struct home: View {
    @State private var newHabit: String = ""
    @State private var showWarning: Bool = false // State to control the warning
    @State private var showEmpty: Bool = false // State to control the warning

    @Binding var selectedTab: Int // Controls the active tab
    @Binding var currentHabit: String

    var body: some View {
        VStack(alignment: .center){
            Image("logo")
                .padding()

            // user inputs a habit to track
            TextField("Enter a habit", text: $newHabit)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button {
                // if there is no tracking in progress
                if !newHabit.isEmpty && currentHabit.isEmpty{
                    currentHabit = newHabit
                    UserDefaults.standard.set(currentHabit, forKey:"habit")

                    newHabit = ""
                    selectedTab = 2
                } else if newHabit.isEmpty || currentHabit == newHabit{ // no input of a habit
                    showEmpty.toggle()
                } else if !newHabit.isEmpty && !currentHabit.isEmpty{ // habit in progress
                    // give out a warning if want to terminate the current progress
                    showWarning = true
                }

                // Hide the error message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showEmpty = false
                    }
                }
            } label: {
                Text("Start a new habit")
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .alert("Warning", isPresented: $showWarning) {
                Button("Terminate Progress") {
                    // Clear current habit and start the new one
                    currentHabit = newHabit
                    UserDefaults.standard.set(currentHabit, forKey: "habit")
                    newHabit = ""
                    selectedTab = 2
                }
                Button("Cancel", role: .cancel) {
                    // close the alert and clear the text box
                    newHabit = ""
                }
            } message: {
                Text("You are currently tracking a habit. Starting a new one will terminate the current progress.")
            }

            if showEmpty {
                Text("No habit submitted or habit already in progress.")
                    .foregroundColor(.red)
                    .padding()
                    .cornerRadius(8)
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Load the habit from UserDefaults on view appear
            if let savedHabit = UserDefaults.standard.string(forKey: "habit"), currentHabit.isEmpty {
                currentHabit = savedHabit
            }
        }
    }
}

// this tab cant be openned if there is no habit tracking in progress
struct progress: View {
    @Binding var currentHabit: String // Binding to track the current habit
    @Binding var selectedTab: Int // Controls the active tab

    @State private var previousHabit: String = ""
    // tracks if habit completed
    @State private var progress: [Bool] = Array(repeating: false, count: 21)
    // Tracks how many days we have completed the habit
    @State private var currentDay: Int = 0
    @State private var currentDate: Date = Date()
    @State private var lastCompletedDate: Date? = nil // Stores the date when the user last completed the habit
    @State private var showResetAlert = false // New state for showing reset alert

    @State private var showSuccessAlert = false // if user completed the 21 daysew

    var body: some View {
        VStack {
            // check if there is a habtit to track (when first installed)
            if currentHabit.isEmpty{
                // If no habit entered, show the alert message
                Text("You need to choose a habit first!")
                    .foregroundColor(.red)
                    .padding()

                Button("Go to Home") {
                    // Go back to Home tab
                    selectedTab = 1
                }
            } else {
                // The actual progress tracking UI when a habit is selected
                Text("Habit tracking: \(currentHabit)")
                    .font(.title)
                    .padding()

                // button to confirm that the user has completed the habit
                Button {
                    if skipped() { // if the user skipped a day
                        showResetAlert = true
                    } else if currentDay < 21{ // Ensure days don't exceed 21
                        progress[currentDay] = true // Mark the current day as complete
                        currentDay += 1 // Move to the next day
                        lastCompletedDate = Date() //store the today's date
                        saveProgress()

                        if currentDay == 21 {
                            showSuccessAlert = true
                        }
                    }
                } label: {
                    Text(currentDay < 21 && canClickToday() ? "Check Day \(currentDay + 1)" : "Habit Completed!")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(currentDay < 21 && canClickToday() ? Color.blue : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding([.leading, .trailing], 20) // Add padding to the left and right sides
                }
                .disabled(currentDay >= 21 || !canClickToday()) // Disable button after 21 days

                // Display 21 circles
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                    ForEach(0..<21, id: \.self) { index in
                        Image(systemName: progress[index] ? "checkmark.circle.fill" : "circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(progress[index] ? .green : .blue)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            // Reset the progress when the view appears or when the habit changes
            if previousHabit != currentHabit {
                resetProgress()
                previousHabit = currentHabit // Update previous habit
            } else {
                loadProgress()
            }

            // update the button if its the next day (checks every 60 secoonds)
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentDate = Date()
            }
        }
        .alert("Skipped a habit", isPresented: $showResetAlert) {
            Button("Reset Progress") {
                // Clear current habit and start the new one
                resetProgress()
            }
            Button("Cancel", role: .cancel) {
                // close the alert
            }
        } message: {
            Text("You missed a day! Your progress will be reset to maintain a consistent streak.")
        }
        .alert("Congratulations!", isPresented: $showSuccessAlert) {
            Button("Start a new habit") {
                // go to home page
                selectedTab = 1
                // reset the progress page
                resetProgress()
            }
        } message: {
            Text("You've successfully completed your 21-day habit formation challenge!")
        }
    }

    private func saveProgress() {
        let defaults = UserDefaults.standard
        // Convert progress array to array of integers (0 for false, 1 for true)
        // $0 is the current element
        let progressData = progress.map { $0 ? 1 : 0 }
        defaults.set(progressData, forKey: "progress")
        defaults.set(currentDay, forKey: "currentDay")
        if let lastCompletedDate = lastCompletedDate {
            defaults.set(lastCompletedDate, forKey: "lastCompletedDate")
        }

        defaults.synchronize() // force save immediately
    }

    private func loadProgress() {
        let defaults = UserDefaults.standard
        // Load and convert back to array of booleans
        if let savedProgress = defaults.array(forKey: "progress") as? [Int] {
            progress = savedProgress.map { $0 == 1 }
        } else { // default
            progress = Array(repeating: false, count: 21)
        }

        currentDay = defaults.integer(forKey: "currentDay")

        if let saveDate = defaults.object(forKey: "lastCompletedDate") as? Date {
            lastCompletedDate = saveDate
        } else {
            lastCompletedDate = nil
        }
    }

    private func resetProgress() {
        progress = Array(repeating: false, count: 21)
        currentDay = 0
        lastCompletedDate = nil
        saveProgress()
    }

    private func skipped() -> Bool {
        guard let lastCompleted = lastCompletedDate else {
            return false
        }

        let calendar = Calendar.current
        let currentDate = Date()

        // Get the difference in days between the last completion and today
        if let daysDifference = calendar.dateComponents([.day], from: lastCompleted, to: currentDate).day {
            // If more than 1 day has passed, we should reset
            return daysDifference > 1
        }
        return false
    }

    private func canClickToday() -> Bool {
        guard let lastCompleted = lastCompletedDate else {
            return true // If no date is stored, allow the button to be clicked
        }

        let calendar = Calendar.current
        //let currentDate = Date()
        // Return true if it's a new day
        return !calendar.isDate(lastCompleted, inSameDayAs: currentDate)
    }
}

struct ContentView: View {
    @State private var selectedTab: Int = 1 // Controls the active tab
    @State private var currentHabit: String = "" // Track the current habit

    var body: some View {
        TabView (selection: $selectedTab){
            home(selectedTab: $selectedTab, currentHabit: $currentHabit)
                .tabItem{
                    Label("Home", systemImage: "house")
                }
                .tag(1)

            progress(currentHabit: $currentHabit, selectedTab: $selectedTab)
                .tabItem{
                    Label("Progress", systemImage: "calendar")
                }
                .tag(2)
        }
    }
}

@main
struct habitApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
