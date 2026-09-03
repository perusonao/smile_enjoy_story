import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_cash_forecast.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_cash_status_presentation.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_financial_status.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_salary.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_state.dart';
import 'package:smile_enjoy_story/game/public_demo/public_demo_workflow_state.dart';

PublicDemoWorkflowState _emptyWorkflow() =>
    PublicDemoWorkflowState(applicants: const [], engineers: const []);

void main() {
  group('PublicDemoCashStatusPresentation.fromForecast', () {
    test('a forecast with no negative month maps to safe, with no shortage month', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: 5000000,
        pendingRevenue: 5000000,
        engineersAssigned: 2,
      );
      final forecast = PublicDemoCashForecast.forecast(
        state: state,
        workflow: _emptyWorkflow(),
      );
      expect(forecast.hasShortage, isFalse);

      final presentation = PublicDemoCashStatusPresentation.fromForecast(forecast);
      expect(presentation.status, PublicDemoCashStatus.safe);
      expect(presentation.shortageMonth, isNull);
    });

    test('a forecast with a first shortage month maps to shortage, carrying that '
        'exact month unchanged', () {
      final baseline = PublicDemoSalary.baselineMonthlyExpenses;
      final state = PublicDemoState.aprilStart().copyWith(
        cash: baseline + (baseline ~/ 2),
        pendingRevenue: 0,
        engineersAssigned: 0,
      );
      final forecast = PublicDemoCashForecast.forecast(
        state: state,
        workflow: _emptyWorkflow(),
        monthsAhead: 3,
      );
      expect(forecast.hasShortage, isTrue);
      expect(forecast.firstShortageMonth, 5);

      final presentation = PublicDemoCashStatusPresentation.fromForecast(forecast);
      expect(presentation.status, PublicDemoCashStatus.shortage);
      expect(presentation.shortageMonth, forecast.firstShortageMonth);
      expect(presentation.shortageMonth, 5);
    });

    test('an empty forecast (close-blocked state) maps to unavailable, never safe, '
        'with no shortage month', () {
      final state = PublicDemoState.aprilStart().copyWith(
        cash: -100000,
        financialStatus: PublicDemoFinancialStatus.bankruptcy,
      );
      final forecast = PublicDemoCashForecast.forecast(
        state: state,
        workflow: _emptyWorkflow(),
      );
      expect(forecast.months, isEmpty);

      final presentation = PublicDemoCashStatusPresentation.fromForecast(forecast);
      expect(presentation.status, PublicDemoCashStatus.unavailable);
      expect(presentation.status, isNot(PublicDemoCashStatus.safe));
      expect(presentation.shortageMonth, isNull);
    });

    test('a fiscal-year-completed empty forecast also maps to unavailable', () {
      final state = PublicDemoState.aprilStart().copyWith(
        month: 15,
        fiscalYearCompleted: true,
      );
      final forecast = PublicDemoCashForecast.forecast(
        state: state,
        workflow: _emptyWorkflow(),
      );
      expect(forecast.months, isEmpty);

      final presentation = PublicDemoCashStatusPresentation.fromForecast(forecast);
      expect(presentation.status, PublicDemoCashStatus.unavailable);
    });

    test('a directly-constructed shortage result never has its shortage month '
        'altered by the mapper', () {
      const forecast = PublicDemoCashForecastResult(
        startMonth: 4,
        months: [
          PublicDemoCashForecastMonth(
            month: 4,
            openingCash: 100,
            cashReceived: 0,
            revenueRecognized: 0,
            monthlyExpenses: 500,
            bonusPaid: 0,
            closingCash: -400,
          ),
        ],
        firstShortageMonth: 4,
      );
      final presentation = PublicDemoCashStatusPresentation.fromForecast(forecast);
      expect(presentation.status, PublicDemoCashStatus.shortage);
      expect(presentation.shortageMonth, 4);
    });

    test('safe and unavailable presentations never carry a shortage month, only '
        'shortage does', () {
      const safeForecast = PublicDemoCashForecastResult(
        startMonth: 4,
        months: [
          PublicDemoCashForecastMonth(
            month: 4,
            openingCash: 1000,
            cashReceived: 0,
            revenueRecognized: 0,
            monthlyExpenses: 100,
            bonusPaid: 0,
            closingCash: 900,
          ),
        ],
        firstShortageMonth: null,
      );
      const unavailableForecast = PublicDemoCashForecastResult(
        startMonth: 15,
        months: [],
        firstShortageMonth: null,
      );

      expect(
        PublicDemoCashStatusPresentation.fromForecast(safeForecast).shortageMonth,
        isNull,
      );
      expect(
        PublicDemoCashStatusPresentation.fromForecast(
          unavailableForecast,
        ).shortageMonth,
        isNull,
      );
    });
  });
}
