Describe 'Grouping using Context' {
    Context 'Test Group 1 Boolean Tests' {
      It 'Should be true' { $true | Should -Be $true }
      It 'Should be true' { $true | Should -BeTrue }
      It 'Should be false' { $false | Should -Be $false }
      It 'Should be false' { $false | Should -BeFalse }
    }
    Context 'Test Group 2 - Negative Assertions' {
      It 'Should not be true' { $false | Should -Not -BeTrue }
      It 'Should be false' { $true | Should -Not -Be $false }
    }
    Context 'Test Group 3 - Calculations' {
      It '$x Should be 42' {
        $x = 42 * 1
        $x | Should -Be 42
      }

      It 'Should be greater than or equal to 33' {
        $y = 3 * 11
        $y | Should -BeGreaterOrEqual 33
      }
      It 'Should with a calculated value' {
        $y = 3
        ($y * 11) | Should -BeGreaterThan 30
      }
    }
    Context 'Test Group 4 - String tests' {
      $testValue = 'ArcaneCode'
      # Test using a Like (not case senstive)
      It "Testing to see if $testValue has arcane" {
        $testValue | Should -BeLike "arcane*"
      }

      # Test using cLike (case sensitive)
      It "Testing to see if $testValue has Arcane" {
        $testValue | Should -BeLikeExactly "Arcane*"
      }
    }
    Context 'Test Group 5 - Array Tests' {
      $myArray = 'ArcaneCode', 'http://arcanecode.red', 'http://arcanecode.me'
      It 'Should contain ArcaneCode' {
        $myArray | Should -Contain 'ArcaneCode'
      }
      It 'Should have 3 items' {
        $myArray | Should -HaveCount 3
      }
    }
}